%-----------------------------------------------------------------------------%
% vim: ft=mercury ts=4 sw=4 et
%-----------------------------------------------------------------------------%
% Copyright (C) 2007 The University of Melbourne.
% This file may only be copied under the terms of the GNU General
% Public License - see the file COPYING in the Mercury distribution.
%-----------------------------------------------------------------------------%
%
% File: delay_partial_inst.m.
% Author: wangp.
%
% This module runs just after mode analysis on mode-correct procedures and
% tries to transform procedures to avoid intermediate partially instantiated
% data structures.  The Erlang backend in particular cannot handle partially
% instantiated data structures (we cannot use destructive update to further
% instantiate data structures since all values are immutable).
%
% There are two situations.  An implied mode call, e.g.
%
%       p(f(_, _))
%
% looks like this after mode checking:
%
%       X := f(V_1, V_2),       % partially instantiated
%       p(Y),
%       X ?= Y
%
% We transform it to this more obvious sequence which doesn't need the
% partially instantiated data structure:
%
%       p(Y),
%       Y ?= f(_, _)
%
% The other situation is if the user writes code that constructs data
% structures with free variables, e.g.
%
%       :- type t
%           --->    t(
%                       a :: int,
%                       b :: int
%                   ).
%
%       F ^ a = 1,
%       F ^ b = 2
%
% After mode checking we get:
%
%       V_1 = 1,
%       F := t(V_1, V_2),       % ground, free
%       V_3 = 2,
%       F => t(V_4, V_3)        % ground, ground
%
% Whereas we would like to see this:
%
%       V_1 = 1,
%       V_2 = 2,
%       F := t(V_1, V_2)
%
%-----------------------------------------------------------------------------%
%
% ALGORITHM
%
% The idea is to remove unifications that produce partially instantiated data
% structures (as the mode checker can't be counted on to move these), and keep
% track of variables which are bound to top-level functors with free arguments.
% In place of the unifications we remove, we insert the unifications for the
% sub-components which are ground.  Only once the variable is ground, because
% all its sub-components are ground, we construct the top-level data
% structure.
%
% The algorithm makes a single forward pass over each procedure.  When we see a
% unification that binds a variable V to a functor f/n with at least one free
% argument, we add an entry to the "construction map" and delete the
% unification.  The construction map records that V was bound to f/n.  We also
% create new "canonical" variables for each of the arguments.
%
% When we later see a deconstruction unification of V we first unify each
% argument in the deconstruction with its corresponding "canonical" variable.
% This way we can always use the canonical variables when it comes time to
% reconstruct V, so we don't need to keep track of aliases.  If the mode of the
% deconstruction unification indicates that V should be ground at end of the
% deconstruction, we insert a construction unification using the canonical
% variables, in place of the deconstruction, and delete V's entry from the
% construction map now.  Otherwise, if V is not ground, we just delete the
% deconstruction unification.
%
% To handle the problem with implied mode calls, we look for complicated
% `can_fail' unifications that have V on the left-hand side.  We transform them
% as in the example above, i.e. instead of unifying a ground variable G with a
% partially instantiated V, we unify G with the functor that V is bound to.
%
% After transforming all the procedures, we requantify and rerun mode analysis,
% which should do the rest.
%
% This algorithm can't handle everything that the mode checker allows, however
% most code written in practice should be okay.  Here's an example of code we
% cannot handle:
%
%   foo(Xs) :-
%       ( Xs = []
%       ; Xs = [1 | _]
%       ),
%       ( Xs = []
%       ; Xs = [_ | []]
%       ).
%
%-----------------------------------------------------------------------------%

:- module check_hlds.delay_partial_inst.
:- interface.

:- import_module hlds.hlds_module.
:- import_module hlds.hlds_pred.

:- import_module io.
:- import_module list.

%-----------------------------------------------------------------------------%

:- pred delay_partial_inst_preds(list(pred_id)::in, list(pred_id)::out,
    module_info::in, module_info::out, io::di, io::uo) is det.

%-----------------------------------------------------------------------------%
%-----------------------------------------------------------------------------%

:- implementation.

:- import_module check_hlds.inst_match.
:- import_module check_hlds.mode_util.
:- import_module hlds.
:- import_module hlds.goal_util.
:- import_module hlds.hlds_goal.
:- import_module hlds.instmap.
:- import_module hlds.passes_aux.
:- import_module hlds.quantification.
:- import_module libs.
:- import_module libs.compiler_util.
:- import_module parse_tree.
:- import_module parse_tree.prog_data.

:- import_module bool.
:- import_module map.
:- import_module maybe.
:- import_module int.
:- import_module pair.
:- import_module set.
:- import_module string.
:- import_module svmap.

%-----------------------------------------------------------------------------%

:- type delay_partial_inst_info
    --->    delay_partial_inst_info(
                % Read-only.
                dpi_module_info :: module_info,

                % Read-write.
                dpi_varset      :: prog_varset,
                dpi_vartypes    :: vartypes,
                dpi_changed     :: bool
            ).

    % A map from the variable to the functor to which it is bound, which maps
    % to the canonical variables assigned for that functor.
    %
    % We can actually only handle the case when a variable is definitely bound
    % to a single functor.  If different disjuncts bind a variable to different
    % functors, then our algorithm won't work.  So why do we use a single map
    % from the variable to (cons_id, canon_vars)?  To handle this case, which
    % can occur from a reasonable predicate definition.
    %
    %   ( X := f
    %   ; X := g
    %   ; X := h(_), fail
    %   ; X := i(_), fail
    %   )
    %
    % We don't want to abort as soon as we see that "X := i(_)" is incompatible
    % with "X := h(_)".  We *will* abort later if need need to look up the sole
    % functor that X could be bound to, and find that there are multiple
    % choices.
    %
:- type construct_map == map(prog_var, canon_vars_map).

:- type canon_vars_map == map(cons_id, prog_vars).

%-----------------------------------------------------------------------------%

delay_partial_inst_preds([], [], !ModuleInfo, !IO).
delay_partial_inst_preds([PredId | PredIds], ChangedPreds, !ModuleInfo, !IO) :-
    module_info_pred_info(!.ModuleInfo, PredId, PredInfo),
    ProcIds = pred_info_non_imported_procids(PredInfo),
    list.foldl3(delay_partial_inst_proc(PredId), ProcIds, !ModuleInfo,
        no, Changed, !IO),
    (
        Changed = yes,
        delay_partial_inst_preds(PredIds, ChangedPreds0, !ModuleInfo, !IO),
        ChangedPreds = [PredId | ChangedPreds0]
    ;
        Changed = no,
        delay_partial_inst_preds(PredIds, ChangedPreds, !ModuleInfo, !IO)
    ).

:- pred delay_partial_inst_proc(pred_id::in, proc_id::in,
    module_info::in, module_info::out, bool::in, bool::out, io::di, io::uo)
    is det.

delay_partial_inst_proc(PredId, ProcId, !ModuleInfo, !Changed, !IO) :-
    write_proc_progress_message("% Delaying partial instantiations in ",
        PredId, ProcId, !.ModuleInfo, !IO),
    module_info_pred_proc_info(!.ModuleInfo, PredId, ProcId, PredInfo,
        ProcInfo0),
    delay_partial_inst_proc_2(!.ModuleInfo, ProcInfo0, MaybeProcInfo),
    (
        MaybeProcInfo = yes(ProcInfo),
        module_info_set_pred_proc_info(PredId, ProcId, PredInfo, ProcInfo,
            !ModuleInfo),
        !:Changed = yes
    ;
        MaybeProcInfo = no
    ).

:- pred delay_partial_inst_proc_2(module_info::in, proc_info::in,
    maybe(proc_info)::out) is det.

delay_partial_inst_proc_2(ModuleInfo, !.ProcInfo, MaybeProcInfo) :-
    proc_info_get_varset(!.ProcInfo, VarSet),
    proc_info_get_vartypes(!.ProcInfo, VarTypes),
    DelayInfo0 = delay_partial_inst_info(ModuleInfo, VarSet, VarTypes, no),

    proc_info_get_initial_instmap(!.ProcInfo, ModuleInfo, InstMap0),
    proc_info_get_goal(!.ProcInfo, Goal0),

    delay_partial_inst_in_goal(InstMap0, Goal0, Goal, map.init, _ConstructMap,
        DelayInfo0, DelayInfo),

    (if DelayInfo ^ dpi_changed = yes then
        proc_info_set_goal(Goal, !ProcInfo),
        proc_info_set_varset(DelayInfo ^ dpi_varset, !ProcInfo),
        proc_info_set_vartypes(DelayInfo ^ dpi_vartypes, !ProcInfo),
        requantify_proc(!ProcInfo),
        MaybeProcInfo = yes(!.ProcInfo)
    else
        MaybeProcInfo = no
    ).

:- pred delay_partial_inst_in_goal(instmap::in, hlds_goal::in, hlds_goal::out,
    construct_map::in, construct_map::out,
    delay_partial_inst_info::in, delay_partial_inst_info::out) is det.

delay_partial_inst_in_goal(InstMap0, Goal0, Goal, !ConstructMap, !DelayInfo) :-
    Goal0 = hlds_goal(GoalExpr0, GoalInfo0),
    (
        GoalExpr0 = conj(ConjType, Goals0),
        delay_partial_inst_in_conj(InstMap0, Goals0, Goals, !ConstructMap,
            !DelayInfo),
        Goal = hlds_goal(conj(ConjType, Goals), GoalInfo0)
    ;
        GoalExpr0 = disj(Goals0),
        %
        % We need to thread the construct map through the disjunctions for when
        % a variable becomes partially constructed in the disjunction.  Each
        % disjunct should be using the same entry for that variable in the
        % construct map.
        %
        % XXX we depend on the fact that (it seems) after mode checking a
        % variable won't become ground in each of the disjuncts, but rather
        % will become ground after the disjunction as a whole.  Otherwise
        % entries could be removed from the construct map in earlier disjuncts
        % that should be visible in later disjuncts.
        %
        delay_partial_inst_in_goals(InstMap0, Goals0, Goals, !ConstructMap,
            !DelayInfo),
        Goal = hlds_goal(disj(Goals), GoalInfo0)
    ;
        GoalExpr0 = negation(NegGoal0),
        delay_partial_inst_in_goal(InstMap0, NegGoal0, NegGoal,
            !.ConstructMap, _, !DelayInfo),
        Goal = hlds_goal(negation(NegGoal), GoalInfo0)
    ;
        GoalExpr0 = switch(Var, CanFail, Cases0),
        delay_partial_inst_in_cases(InstMap0, Cases0, Cases, !ConstructMap,
            !DelayInfo),
        Goal = hlds_goal(switch(Var, CanFail, Cases), GoalInfo0)
    ;
        GoalExpr0 = if_then_else(Vars, Cond0, Then0, Else0),
        update_instmap(Cond0, InstMap0, InstMapThen),
        delay_partial_inst_in_goal(InstMap0, Cond0, Cond, !ConstructMap,
            !DelayInfo),
        delay_partial_inst_in_goal(InstMapThen, Then0, Then, !ConstructMap,
            !DelayInfo),
        delay_partial_inst_in_goal(InstMap0, Else0, Else, !ConstructMap,
            !DelayInfo),
        Goal = hlds_goal(if_then_else(Vars, Cond, Then, Else), GoalInfo0)
    ;
        GoalExpr0 = scope(Reason, SubGoal0),
        delay_partial_inst_in_goal(InstMap0, SubGoal0, SubGoal,
            !.ConstructMap, _, !DelayInfo),
        Goal = hlds_goal(scope(Reason, SubGoal), GoalInfo0)
    ;
        GoalExpr0 = unify(LHS, RHS0, Mode, Unify, Context),
        (
            Unify = construct(Var, ConsId, Args, UniModes, _, _, _),
            (if
                % Is this construction of the form
                %   V = f(A1, A2, A3, ...)
                % and at least one of the arguments is free?
                %
                ConsId = cons(_, _),
                ModuleInfo = !.DelayInfo ^ dpi_module_info,
                some [RhsAfter] (
                    list.member(_ -> _ - RhsAfter, UniModes),
                    inst_is_free(ModuleInfo, RhsAfter)
                )
            then
                % Add an entry for Var to the construct map if it doesn't exist
                % already, otherwise look up the canonical variables.
                (if
                    map.search(!.ConstructMap, Var, CanonVarsMap0),
                    map.search(CanonVarsMap0, ConsId, CanonVars0)
                then
                    CanonVars = CanonVars0
                else
                    create_canonical_variables(Args, CanonVars, !DelayInfo),
                    add_to_construct_map(Var, ConsId, CanonVars, !ConstructMap)
                ),

                % Unify the canonical variables and corresponding ground
                % arguments (if any).
                goal_info_get_context(GoalInfo0, ProgContext),
                SubUnifyGoals = list.filter_map_corresponding3(
                    maybe_unify_var_with_ground_var(ModuleInfo, ProgContext),
                    CanonVars, Args, UniModes),
                conj_list_to_goal(SubUnifyGoals, GoalInfo0, Goal),

                % Mark the procedure as changed.
                !DelayInfo ^ dpi_changed := yes

            else if
                % Tranform lambda goals as well.  Non-local variables in lambda
                % goals must be ground so we don't carry the construct map into
                % the lambda goal.
                RHS0 = rhs_lambda_goal(Purity, PredOrFunc, EvalMethod,
                    NonLocals, LambdaQuantVars, Modues, Detism, LambdaGoal0)
            then
                delay_partial_inst_in_goal(InstMap0, LambdaGoal0, LambdaGoal,
                    map.init, _ConstructMap, !DelayInfo),
                RHS = rhs_lambda_goal(Purity, PredOrFunc, EvalMethod,
                    NonLocals, LambdaQuantVars, Modues, Detism, LambdaGoal),
                GoalExpr = unify(LHS, RHS, Mode, Unify, Context),
                Goal = hlds_goal(GoalExpr, GoalInfo0)
            else
                Goal = Goal0
            )
        ;
            Unify = deconstruct(Var, ConsId, DeconArgs, UniModes,
                _CanFail, _CanCGC),
            (if
                map.search(!.ConstructMap, Var, CanonVarsMap0),
                map.search(CanonVarsMap0, ConsId, CanonArgs)
            then
                % Unify each ground argument with the corresponding canonical
                % variable.
                ModuleInfo = !.DelayInfo ^ dpi_module_info,
                goal_info_get_context(GoalInfo0, ProgContext),
                SubUnifyGoals = list.filter_map_corresponding3(
                    maybe_unify_var_with_ground_var(ModuleInfo, ProgContext),
                    CanonArgs, DeconArgs, UniModes),

                % Construct Var if it should be ground now.
                Mode = LHS_Mode - _RHS_Mode,
                FinalInst = mode_get_final_inst(ModuleInfo, LHS_Mode),
                (if inst_is_ground(ModuleInfo, FinalInst) then
                    construct_functor(Var, ConsId, CanonArgs, ConstructGoal),

                    % Delete the variable on the LHS from the construct map
                    % since it has been constructed.
                    map.delete(CanonVarsMap0, ConsId, CanonVarsMap),
                    svmap.det_update(Var, CanonVarsMap, !ConstructMap),

                    ConjList = SubUnifyGoals ++ [ConstructGoal]
                else
                    ConjList = SubUnifyGoals
                ),
                conj_list_to_goal(ConjList, GoalInfo0, Goal)
            else
                Goal = Goal0
            )
        ;
            Unify = complicated_unify(_UniMode, CanFail, _TypeInfos),
            %
            % Deal with tests generated for calls to implied modes.
            %
            %       LHS := f(_),
            %       p(RHS),
            %       LHS ?= RHS
            %   ===>
            %       p(RHS),
            %       RHS ?= f(_),
            %       LHS := RHS
            %
            % XXX I have not seen a case where the LHS and RHS are swapped
            % but we should handle that if it comes up.
            %
            (if
                CanFail = can_fail,
                RHS0 = rhs_var(RHSVar),
                get_sole_cons_id_and_canon_vars(!.ConstructMap, LHS, ConsId,
                    CanonArgs)
            then
                goal_info_get_context(GoalInfo0, ProgContext),
                create_pure_atomic_complicated_unification(RHSVar,
                    rhs_functor(ConsId, no, CanonArgs),
                    ProgContext, umc_explicit, [], TestGoal),
                create_pure_atomic_complicated_unification(LHS, RHS0,
                    ProgContext, umc_implicit("delay_partial_inst"), [],
                    AssignGoal),
                conjoin_goals(TestGoal, AssignGoal, Goal)
            else
                Goal = Goal0
            )
        ;
            ( Unify = assign(_, _)
            ; Unify = simple_test(_, _)
            ),
            Goal = Goal0
        )
    ;
        ( GoalExpr0 = generic_call(_, _, _, _)
        ; GoalExpr0 = plain_call(_, _, _, _, _, _)
        ; GoalExpr0 = call_foreign_proc(_, _, _, _, _, _, _)
        ),
        Goal = Goal0
    ;
        GoalExpr0 = shorthand(_),
        % These should have been expanded out by now.
        unexpected(this_file,
            "delay_partial_inst_in_goal: unexpected shorthand")
    ).

:- pred create_canonical_variables(prog_vars::in, prog_vars::out,
    delay_partial_inst_info::in, delay_partial_inst_info::out) is det.

create_canonical_variables(OrigVars, CanonVars, !DelayInfo) :-
    VarSet0 = !.DelayInfo ^ dpi_varset,
    VarTypes0 = !.DelayInfo ^ dpi_vartypes,
    create_variables(OrigVars, VarSet0, VarTypes0,
        VarSet0, VarSet, VarTypes0, VarTypes, map.init, Subn),
    MustRename = yes,
    rename_var_list(MustRename, Subn, OrigVars, CanonVars),
    !DelayInfo ^ dpi_varset := VarSet,
    !DelayInfo ^ dpi_vartypes := VarTypes.

:- pred add_to_construct_map(prog_var::in, cons_id::in, prog_vars::in,
    construct_map::in, construct_map::out) is det.

add_to_construct_map(Var, ConsId, CanonVars, !ConstructMap) :-
    ( map.search(!.ConstructMap, Var, ConsIdMap0) ->
        ConsIdMap1 = ConsIdMap0
    ;
        ConsIdMap1 = map.init
    ),
    map.det_insert(ConsIdMap1, ConsId, CanonVars, ConsIdMap),
    svmap.set(Var, ConsIdMap, !ConstructMap).

:- pred get_sole_cons_id_and_canon_vars(construct_map::in, prog_var::in,
    cons_id::out, prog_vars::out) is semidet.

get_sole_cons_id_and_canon_vars(ConstructMap, Var, ConsId, CanonVars) :-
    map.search(ConstructMap, Var, CanonVarsMap),
    List = map.to_assoc_list(CanonVarsMap),
    (
        List = [],
        fail
    ;
        List = [ConsId - CanonVars | Rest],
        (
            Rest = []
        ;
            Rest = [_ | _],
            % This algorithm does not work if a variable could be bound to
            % multiple functors when we try to do a tag test against it.
            % XXX report a nicer error message
            sorry(this_file,
                "delaying partial instantiations when variable could be " ++
                "bound to multiple functors")
        )
    ).

:- func maybe_unify_var_with_ground_var(module_info::in, prog_context::in,
    prog_var::in, prog_var::in, uni_mode::in) = (hlds_goal::out) is semidet.

maybe_unify_var_with_ground_var(ModuleInfo, Context, LhsVar, RhsVar, ArgMode)
        = Goal :-
    ArgMode = (_ - _ -> Inst - _),
    inst_is_ground(ModuleInfo, Inst),
    create_pure_atomic_complicated_unification(LhsVar, rhs_var(RhsVar),
        Context, umc_implicit("delay_partial_inst"), [], Goal).

%-----------------------------------------------------------------------------%

:- pred delay_partial_inst_in_conj(instmap::in,
    list(hlds_goal)::in, list(hlds_goal)::out,
    construct_map::in, construct_map::out,
    delay_partial_inst_info::in, delay_partial_inst_info::out) is det.

delay_partial_inst_in_conj(_, [], [], !ConstructMap, !DelayInfo).
delay_partial_inst_in_conj(InstMap0, [Goal0 | Goals0], Goals, !ConstructMap,
        !DelayInfo) :-
    delay_partial_inst_in_goal(InstMap0, Goal0, Goal1, !ConstructMap,
        !DelayInfo),
    update_instmap(Goal0, InstMap0, InstMap1),
    delay_partial_inst_in_conj(InstMap1, Goals0, Goals1, !ConstructMap,
        !DelayInfo),
    goal_to_conj_list(Goal1, Goal1List),
    Goals = Goal1List ++ Goals1.

:- pred delay_partial_inst_in_goals(instmap::in,
    list(hlds_goal)::in, list(hlds_goal)::out,
    construct_map::in, construct_map::out,
    delay_partial_inst_info::in, delay_partial_inst_info::out) is det.

delay_partial_inst_in_goals(_, [], [], !ConstructMap, !DelayInfo).
delay_partial_inst_in_goals(InstMap0,
        [Goal0 | Goals0], [Goal | Goals], !ConstructMap, !DelayInfo) :-
    delay_partial_inst_in_goal(InstMap0, Goal0, Goal, !ConstructMap,
        !DelayInfo),
    delay_partial_inst_in_goals(InstMap0, Goals0, Goals, !ConstructMap,
        !DelayInfo).

:- pred delay_partial_inst_in_cases(instmap::in,
    list(case)::in, list(case)::out, construct_map::in, construct_map::out,
    delay_partial_inst_info::in, delay_partial_inst_info::out) is det.

delay_partial_inst_in_cases(_, [], [], !ConstructMap, !DelayInfo).
delay_partial_inst_in_cases(InstMap0,
        [case(Cons, Goal0) | Cases0], [case(Cons, Goal) | Cases],
        !ConstructMap, !DelayInfo) :-
    delay_partial_inst_in_goal(InstMap0, Goal0, Goal, !ConstructMap,
        !DelayInfo),
    delay_partial_inst_in_cases(InstMap0, Cases0, Cases, !ConstructMap,
        !DelayInfo).

%-----------------------------------------------------------------------------%

:- func this_file = string.

this_file = "delay_partial_inst.m".

%-----------------------------------------------------------------------------%
:- end_module delay_partial_inst.
%-----------------------------------------------------------------------------%