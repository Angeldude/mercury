%-----------------------------------------------------------------------------%
% Copyright (C) 1995-1999 The University of Melbourne.
% This file may only be copied under the terms of the GNU General
% Public License - see the file COPYING in the Mercury distribution.
%-----------------------------------------------------------------------------%
%
% file: inst_match.m
% author: fjh
%
% This module defines some utility routines for comparing insts
% that are used by modes.m and det_analysis.m.

/*
The handling of `any' insts is not complete.  (See also inst_util.m)
It would be nice to allow `free' to match `any', but right now we
only allow a few special cases of that.
The reason is that although the mode analysis would be pretty
straight-forward, generating the correct code is quite a bit trickier.
modes.m would have to be changed to handle the implicit
conversions from `free'/`bound'/`ground' to `any' at

	(1) procedure calls (this is just an extension of implied modes)
		currently we support only the easy cases of this
	(2) the end of branched goals
	(3) the end of predicates.

Since that is not yet done, we currently require the user to
insert explicit calls to initialize constraint variables.

We do allow `bound' and `ground' to match `any', based on the
assumption that `bound' and `ground' are represented in the same
way as `any', i.e. that we use the type system rather than the
mode system to distinguish between different representations.
*/

%-----------------------------------------------------------------------------%

:- module inst_match.

:- interface.

:- import_module hlds_module, prog_data, (inst), instmap.
:- import_module inst_table.

:- import_module list, std_util, map.

%-----------------------------------------------------------------------------%

:- pred inst_expand(instmap, inst_table, module_info, inst, inst).
:- mode inst_expand(in, in, in, in, out) is det.

	% inst_expand(InstTable, ModuleInfo, Inst0, Inst) checks if the
	% top-level % part of the inst is a defined inst or an alias, and
	% if so replaces it with the definition.

:- pred inst_expand_defined_inst(inst_table, module_info, inst, inst).
:- mode inst_expand_defined_inst(in, in, in, out) is det.

	% inst_expand_defined_inst(InstTable, ModuleInfo, Inst0, Inst) checks
	% if the top-level part of the inst is a defined inst, and if so
	% replaces it with the definition.

%-----------------------------------------------------------------------------%

:- type alias_map == map(inst_key, maybe(inst_key)).

:- pred inst_matches_initial(inst, instmap, inst, instmap, inst_table,
		module_info, alias_map, alias_map).
:- mode inst_matches_initial(in, in, in, in, in, in, in, out) is semidet.

:- pred inst_matches_final(inst, instmap, inst, instmap, inst_table,
		module_info, alias_map, alias_map).
:- mode inst_matches_final(in, in, in, in, in, in, in, out) is semidet.

	% inst_matches_initial(InstA, InstMapA, InstB, InstMapB, InstTable,
	%		ModuleInfo):
	%	Succeed iff `InstA' specifies at least as much
	%	information as `InstB', and in those parts where they
	%	specify the same information, `InstA' is at least as
	%	instantiated as `InstB'.
	%	Thus, inst_matches_initial(not_reached, ground, _)
	%	succeeds, since not_reached contains more information
	%	than ground - but not vice versa.  Similarly,
	%	inst_matches_initial(bound(a), bound(a;b), _) should
	%	succeed, but not vice versa.

	% inst_matches_final(InstA, InstMapA, InstB, InstMapB, InstTable,
	%		ModuleInfo):
	%	Succeed iff InstA is compatible with InstB,
	%	i.e. iff InstA will satisfy the final inst
	%	requirement InstB.  This is true if the
	%	information specified by InstA is at least as
	%	great as that specified by InstB, and where the information
	%	is the same and both insts specify a binding, the binding
	%	must be identical.
	%
	%	The difference between inst_matches_initial and
	%	inst_matches_final is that inst_matches_initial requires
	%	only something which is at least as instantiated,
	%	whereas this predicate wants something which is an
	%	exact match (or not reachable).
	%
	%	Note that this predicate is not symmetric,
	%	because of the existence of `not_reached' insts:
	%	not_reached matches_final with anything,
	%	but not everything matches_final with not_reached -
	%	in fact only not_reached matches_final with not_reached.
	%	It is also asymmetric with respect to unique insts.

	% It might be a good idea to fold inst_matches_initial and
	% inst_matches_final into a single predicate inst_matches(When, ...)
	% where When is either `initial' or `final'.

:- pred inst_matches_initial_ignore_aliasing(inst, instmap, inst, instmap,
		inst_table, module_info).
:- mode inst_matches_initial_ignore_aliasing(in, in, in, in, in, in)
		is semidet.

:- pred inst_matches_final_ignore_aliasing(inst, instmap, inst, instmap,
		inst_table, module_info).
:- mode inst_matches_final_ignore_aliasing(in, in, in, in, in, in) is semidet.

	% inst_matches_initial_ignore_aliasing and
	% inst_matches_final_ignore_aliasing are the same as
	% inst_matches_initial and inst_matches_final, respectively except that
	% alias insts are expanded and ignored.
	% These predicates can be used in situations where we are only
	% interested in comparing bindings and uniqueness between insts rather
	% than determining whether the insts of a set of variables match
	% the required insts for a procedure's arguments.

:- pred unique_matches_initial(uniqueness, uniqueness).
:- mode unique_matches_initial(in, in) is semidet.

	% unique_matches_initial(A, B) succeeds if A >= B in the ordering
	% clobbered < mostly_clobbered < shared < mostly_unique < unique

:- pred unique_matches_final(uniqueness, uniqueness).
:- mode unique_matches_final(in, in) is semidet.

	% unique_matches_final(A, B) succeeds if A >= B in the ordering
	% clobbered < mostly_clobbered < shared < mostly_unique < unique

:- pred inst_matches_binding(inst, instmap, inst, instmap, inst_table,
		module_info).
:- mode inst_matches_binding(in, in, in, in, in, in) is semidet.

	% inst_matches_binding(InstA, InstMapA, InstB, InstMapB, InstTable,
	%		ModuleInfo):
	%	 Succeed iff the binding of InstA is definitely exactly the
	%	 same as that of InstB.  This is the same as
	%	 inst_matches_final except that it ignores uniqueness, and
	%	 that `any' does not match itself.  It is used to check
	%	 whether variables get bound in negated contexts.

%-----------------------------------------------------------------------------%

	% pred_inst_matches(PredInstA, PredInstB, InstTable, ModuleInfo)
	% 	Succeeds if PredInstA specifies a pred that can
	%	be used wherever and whenever PredInstB could be used.
	%	This is true if they both have the same PredOrFunc indicator
	%	and the same determinism, and if the arguments match
	%	using pred_inst_argmodes_match.
	%
:- pred pred_inst_matches(pred_inst_info, instmap, pred_inst_info, instmap,
		inst_table, module_info).
:- mode pred_inst_matches(in, in, in, in, in, in) is semidet.

%-----------------------------------------------------------------------------%

/*
** Predicates to test various properties of insts.
** Note that `not_reached' insts are considered to satisfy
** all of these predicates except inst_is_clobbered.
*/

	% succeed if the inst is fully ground (i.e. contains only
	% `ground', `bound', and `not_reached' insts, with no `free'
	% or `any' insts).
:- pred inst_is_ground(inst, instmap, inst_table, module_info).
:- mode inst_is_ground(in, in, in, in) is semidet.

	% succeed if the inst is not partly free (i.e. contains only
	% `any', `ground', `bound', and `not_reached' insts, with no
	% `free' insts).
:- pred inst_is_ground_or_any(inst, instmap, inst_table, module_info).
:- mode inst_is_ground_or_any(in, in, in, in) is semidet.

	% succeed if the inst is fully ground and has a higher order
	% inst.
:- pred inst_is_higher_order_ground(inst, instmap, inst_table, module_info).
:- mode inst_is_higher_order_ground(in, in, in, in) is semidet.

	% succeed if the inst is `mostly_unique' or `unique'
:- pred inst_is_mostly_unique(inst, instmap, inst_table, module_info).
:- mode inst_is_mostly_unique(in, in, in, in) is semidet.

	% succeed if the inst is `unique'
:- pred inst_is_unique(inst, instmap, inst_table, module_info).
:- mode inst_is_unique(in, in, in, in) is semidet.

	% succeed if the inst is not `mostly_unique' or `unique'
:- pred inst_is_not_partly_unique(inst, instmap, inst_table, module_info).
:- mode inst_is_not_partly_unique(in, in, in, in) is semidet.

	% succeed if the inst is not `unique'
:- pred inst_is_not_fully_unique(inst, instmap, inst_table, module_info).
:- mode inst_is_not_fully_unique(in, in, in, in) is semidet.

:- pred inst_is_clobbered(inst, instmap, inst_table, module_info).
:- mode inst_is_clobbered(in, in, in, in) is semidet.

:- pred inst_list_is_ground(list(inst), instmap, inst_table, module_info).
:- mode inst_list_is_ground(in, in, in, in) is semidet.

:- pred inst_list_is_ground_or_any(list(inst), instmap, inst_table,
		module_info).
:- mode inst_list_is_ground_or_any(in, in, in, in) is semidet.

:- pred inst_list_is_unique(list(inst), instmap, inst_table, module_info).
:- mode inst_list_is_unique(in, in, in, in) is semidet.

:- pred inst_list_is_mostly_unique(list(inst), instmap, inst_table,
		module_info).
:- mode inst_list_is_mostly_unique(in, in, in, in) is semidet.

:- pred inst_list_is_not_partly_unique(list(inst), instmap, inst_table,
		module_info).
:- mode inst_list_is_not_partly_unique(in, in, in, in) is semidet.

:- pred inst_list_is_not_fully_unique(list(inst), instmap, inst_table, module_info).
:- mode inst_list_is_not_fully_unique(in, in, in, in) is semidet.

:- pred bound_inst_list_is_ground(list(bound_inst), instmap, inst_table, module_info).
:- mode bound_inst_list_is_ground(in, in, in, in) is semidet.

:- pred bound_inst_list_is_ground_or_any(list(bound_inst), instmap, inst_table,
		module_info).
:- mode bound_inst_list_is_ground_or_any(in, in, in, in) is semidet.

:- pred bound_inst_list_is_unique(list(bound_inst), instmap, inst_table, module_info).
:- mode bound_inst_list_is_unique(in, in, in, in) is semidet.

:- pred bound_inst_list_is_mostly_unique(list(bound_inst), instmap, inst_table,
		module_info).
:- mode bound_inst_list_is_mostly_unique(in, in, in, in) is semidet.

:- pred bound_inst_list_is_not_partly_unique(list(bound_inst), instmap, inst_table,
		module_info).
:- mode bound_inst_list_is_not_partly_unique(in, in, in, in) is semidet.

:- pred bound_inst_list_is_not_fully_unique(list(bound_inst), instmap, inst_table,
		module_info).
:- mode bound_inst_list_is_not_fully_unique(in, in, in, in) is semidet.

:- pred inst_is_bound(inst, instmap, inst_table, module_info).
:- mode inst_is_bound(in, in, in, in) is semidet.

:- pred inst_is_free_alias(inst, instmap, inst_table, module_info).
:- mode inst_is_free_alias(in, in, in, in) is semidet.

:- pred inst_contains_free_alias(inst, instmap, inst_table, module_info).
:- mode inst_contains_free_alias(in, in, in, in) is semidet.

:- pred inst_is_free(inst, instmap, inst_table, module_info).
:- mode inst_is_free(in, in, in, in) is semidet.

:- pred inst_list_is_free(list(inst), instmap, inst_table, module_info).
:- mode inst_list_is_free(in, in, in, in) is semidet.

:- pred bound_inst_list_is_free(list(bound_inst), instmap, inst_table,
		module_info).
:- mode bound_inst_list_is_free(in, in, in, in) is semidet.

:- pred inst_is_bound_to_functors(inst, instmap, inst_table, module_info,
		list(bound_inst)).
:- mode inst_is_bound_to_functors(in, in, in, in, out) is semidet.

	% succeed if the inst has a run-time representation.
:- pred inst_has_representation(inst, instmap, inst_table, type, module_info).
:- mode inst_has_representation(in, in, in, in, in) is semidet.

%-----------------------------------------------------------------------------%

	% Succeed iff the specified inst contains (directly or indirectly)
	% the specified inst_name.

:- pred inst_contains_instname(inst, instmap, inst_table, module_info,
		inst_name).
:- mode inst_contains_instname(in, in, in, in, in) is semidet.

:- pred inst_contains_inst_key(instmap, inst_table, module_info, inst, 
		inst_key).
:- mode inst_contains_inst_key(in, in, in, in, in) is semidet.

	% Succeed iff the specified inst contains any alias insts.
:- pred inst_contains_aliases(inst, inst_table, module_info).
:- mode inst_contains_aliases(in, in, in) is semidet.

	% Nondeterministically produce all the inst_vars contained
	% in the specified list of modes.

:- pred mode_list_contains_inst_var(list(mode), instmap, inst_table,
		module_info, inst_var).
:- mode mode_list_contains_inst_var(in, in, in, in, out) is nondet.

	% Given a list of insts, and a corresponding list of livenesses,
	% return true iff for every element in the list of insts, either
	% the elemement is ground or the corresponding element in the liveness
	% list is dead.

:- pred inst_list_is_ground_or_dead(list(inst), list(is_live),
		instmap, inst_table, module_info).
:- mode inst_list_is_ground_or_dead(in, in, in, in, in) is semidet.

	% Given a list of insts, and a corresponding list of livenesses,
	% return true iff for every element in the list of insts, either
	% the element is ground or any, or the corresponding element
	% in the liveness list is dead.

:- pred inst_list_is_ground_or_any_or_dead(list(inst), list(is_live),
		instmap, inst_table, module_info).
:- mode inst_list_is_ground_or_any_or_dead(in, in, in, in, in) is semidet.

%-----------------------------------------------------------------------------%
%-----------------------------------------------------------------------------%

:- implementation.
:- import_module hlds_data, mode_util, prog_data, inst_util, type_util.
:- import_module list, set, term, require, bool.

inst_matches_initial(InstA, InstMapA, InstB, InstMapB,
			InstTable, ModuleInfo, AliasMap0, AliasMap) :-
	set__init(Expansions),
	IgnoreAliasing = no,
	inst_matches_initial_2(InstA, InstMapA, InstB, InstMapB, InstTable,
		ModuleInfo, Expansions, IgnoreAliasing, AliasMap0, AliasMap).

inst_matches_initial_ignore_aliasing(InstA, InstMapA, InstB, InstMapB,
			InstTable, ModuleInfo) :-
	set__init(Expansions),
	map__init(AliasMap0),
	IgnoreAliasing = yes,
	inst_matches_initial_2(InstA, InstMapA, InstB, InstMapB, InstTable,
		ModuleInfo, Expansions, IgnoreAliasing, AliasMap0, _AliasMap).

:- type expansions == set(pair(inst)).

:- pred inst_matches_initial_2(inst, instmap, inst, instmap, inst_table,
		module_info, expansions, bool, alias_map, alias_map).
:- mode inst_matches_initial_2(in, in, in, in, in, in, in, in, in, out)
		is semidet.

inst_matches_initial_2(InstA, InstMapA, InstB, InstMapB, InstTable, ModuleInfo,
		Expansions, IgnoreAliasing, AliasMap0, AliasMap) :-
	ThisExpansion = InstA - InstB,
	( set__member(ThisExpansion, Expansions) ->
		AliasMap = AliasMap0
/********* 
		% does this test improve efficiency??
	; InstA = InstB ->
		true
**********/
	;
		inst_matches_aliasing(IgnoreAliasing, InstA, InstB,
			InstMapA, AliasMap0, AliasMap1),

		inst_expand(InstMapA, InstTable, ModuleInfo, InstA, InstA2),
		inst_expand(InstMapB, InstTable, ModuleInfo, InstB, InstB2),
		set__insert(Expansions, ThisExpansion, Expansions2),
		inst_matches_initial_3(InstA2, InstMapA, InstB2, InstMapB,
			InstTable, ModuleInfo, Expansions2, IgnoreAliasing,
			AliasMap1, AliasMap)
	).

:- pred inst_matches_initial_3(inst, instmap, inst, instmap, inst_table,
		module_info, expansions, bool, alias_map, alias_map).
:- mode inst_matches_initial_3(in, in, in, in, in, in, in, in, in, out)
		is semidet.

	% To avoid infinite regress, we assume that
	% inst_matches_initial is true for any pairs of insts which
	% occur in `Expansions'.

inst_matches_initial_3(any(UniqA), _, any(UniqB), _, _, _, _, _, AM, AM) :-
	unique_matches_initial(UniqA, UniqB).
inst_matches_initial_3(any(_), _, free(unique), _, _, _, _, _, AM, AM).
inst_matches_initial_3(free(unique), _, any(_), _, _, _, _, _, AM, AM).
inst_matches_initial_3(free(alias), _, free(alias), _, _, _, _, _, AM, AM).
			% AAA free(alias) should match_initial free(unique)
			% and vice-versa.  They will as soon as the mode
			% checker supports the implied modes that would result.
inst_matches_initial_3(free(unique), _, free(unique), _, _, _, _, _, AM, AM).
inst_matches_initial_3(bound(UniqA, ListA), InstMapA, any(UniqB), _InstMapB,
		InstTable, ModuleInfo, _, _, AM, AM) :-
	unique_matches_initial(UniqA, UniqB),
	bound_inst_list_matches_uniq(ListA, UniqB, InstMapA, InstTable,
		ModuleInfo).
inst_matches_initial_3(bound(_Uniq, _List), _, free(_), _, _, _, _, _, AM, AM).
inst_matches_initial_3(bound(UniqA, ListA), InstMapA, bound(UniqB, ListB), 
		InstMapB, InstTable, ModuleInfo, Expansions, IgnoreAliasing,
		AliasMap0, AliasMap) :-
	unique_matches_initial(UniqA, UniqB),
	bound_inst_list_matches_initial(ListA, InstMapA, ListB, InstMapB,
		InstTable, ModuleInfo, Expansions, IgnoreAliasing,
		AliasMap0, AliasMap).
inst_matches_initial_3(bound(UniqA, ListA), InstMapA, ground(UniqB, no),
		_InstMapB, InstTable, ModuleInfo, _, _, AM, AM) :-
	unique_matches_initial(UniqA, UniqB),
	bound_inst_list_is_ground(ListA, InstMapA, InstTable, ModuleInfo),
	bound_inst_list_matches_uniq(ListA, UniqB, InstMapA, InstTable,
			ModuleInfo).
inst_matches_initial_3(bound(Uniq, List), InstMapA, abstract_inst(_,_),
		_InstMapB, InstTable, ModuleInfo, _, _, AM, AM) :-
	Uniq = unique,
	bound_inst_list_is_ground(List, InstMapA, InstTable, ModuleInfo),
	bound_inst_list_is_unique(List, InstMapA, InstTable, ModuleInfo).
inst_matches_initial_3(bound(Uniq, List), InstMapA, abstract_inst(_,_),
		_InstMapB, InstTable, ModuleInfo, _, _, AM, AM) :-
	Uniq = mostly_unique,
	bound_inst_list_is_ground(List, InstMapA, InstTable, ModuleInfo),
	bound_inst_list_is_mostly_unique(List, InstMapA, InstTable, ModuleInfo).
inst_matches_initial_3(ground(UniqA, _PredInst), _, any(UniqB), _, _, _, _,
		_, AM, AM) :-
	unique_matches_initial(UniqA, UniqB).
inst_matches_initial_3(ground(_Uniq, _PredInst), _, free(_), _, _, _, _, _,
		AM, AM).
inst_matches_initial_3(ground(UniqA, _), _, bound(UniqB, List), InstMapB,
		InstTable, ModuleInfo, _, _, _, _) :-
	unique_matches_initial(UniqA, UniqB),
	uniq_matches_bound_inst_list(UniqA, List, InstMapB, InstTable,
			ModuleInfo),
	fail.	% XXX BUG! should fail only if 
		% List does not include all the constructors for the type,
		% or if List contains some not_reached insts.
		% Should succeed if List contains all the constructors
		% for the type.  Problem is we don't know what the type was :-(
inst_matches_initial_3(ground(UniqA, PredInstA), InstMapA,
		ground(UniqB, PredInstB), InstMapB,
		InstTable, ModuleInfo, _, _, AM, AM) :-
	maybe_pred_inst_matches_initial(PredInstA, InstMapA, PredInstB,
		InstMapB, InstTable, ModuleInfo),
	unique_matches_initial(UniqA, UniqB).
inst_matches_initial_3(ground(_UniqA, no), _, abstract_inst(_,_), _, _, _, _,
		_, AM, AM) :-
		% I don't know what this should do.
		% Abstract insts aren't really supported.
	error("inst_matches_initial(ground, abstract_inst) == ??").
inst_matches_initial_3(abstract_inst(_,_), _, any(shared), _, _, _, _, _,
		AM, AM).
inst_matches_initial_3(abstract_inst(_,_), _, free(_), _, _, _, _, _, AM, AM).
inst_matches_initial_3(abstract_inst(Name, ArgsA), InstMapA,
		abstract_inst(Name, ArgsB), InstMapB, InstTable, ModuleInfo,
		Expansions, IgnoreAliasing, AliasMap0, AliasMap) :-
	inst_list_matches_initial(ArgsA, InstMapA, ArgsB, InstMapB,
		InstTable, ModuleInfo, Expansions, IgnoreAliasing,
		AliasMap0, AliasMap).
inst_matches_initial_3(not_reached, _, _, _, _, _, _, _, AM, AM).

%-----------------------------------------------------------------------------%

:- pred maybe_pred_inst_matches_initial(maybe(pred_inst_info), instmap,
		maybe(pred_inst_info), instmap, inst_table, module_info).
:- mode maybe_pred_inst_matches_initial(in, in, in, in, in, in) is semidet.

maybe_pred_inst_matches_initial(no, _, no, _, _, _).
maybe_pred_inst_matches_initial(yes(_), _, no, _, _, _).
maybe_pred_inst_matches_initial(yes(PredInstA), InstMapA, yes(PredInstB),
		InstMapB, InstTable, ModuleInfo) :-
	pred_inst_matches(PredInstA, InstMapA, PredInstB, InstMapB,
		InstTable, ModuleInfo).

pred_inst_matches(PredInstA, InstMapA, PredInstB, InstMapB, InstTable,
		ModuleInfo) :-
	set__init(Expansions),
	pred_inst_matches_2(PredInstA, InstMapA, PredInstB, InstMapB,
		InstTable, ModuleInfo, Expansions).

	% pred_inst_matches_2(PredInstA, InstMapA, PredInstB, InstMapB,
	%		InstTable, ModuleInfo, Expansions)
	%	Same as pred_inst_matches/4, except that inst pairs in
	%	Expansions are assumed to match_final each other.
	%	(This avoids infinite loops when calling inst_matches_final
	%	on higher-order recursive insts.)
	%
:- pred pred_inst_matches_2(pred_inst_info, instmap, pred_inst_info, instmap,
		inst_table, module_info, expansions).
:- mode pred_inst_matches_2(in, in, in, in, in, in, in) is semidet.

pred_inst_matches_2(
		pred_inst_info(PredOrFunc, argument_modes(InstTableA, ModesA),
				Det),
		InstMapA,
		pred_inst_info(PredOrFunc, argument_modes(InstTableB, ModesB0),
				Det),
		InstMapB, _InstTable, ModuleInfo, Expansions) :-
	inst_table_create_sub(InstTableA, InstTableB, Sub, InstTable),
	list__map(apply_inst_table_sub_mode(Sub), ModesB0, ModesB),

	% Initialise alias_maps for comparing aliases between the modes.
	map__init(AliasMapA0),
	map__init(AliasMapB0),
	pred_inst_argmodes_matches(ModesA, InstMapA, ModesB, InstMapB,
		InstTable, ModuleInfo, Expansions, AliasMapA0, AliasMapB0).

	% pred_inst_matches_argmodes(ModesA, ModesB, ModuleInfo, Expansions):
	% succeeds if the initial insts of ModesB specify at least as
	% much information as, and the same binding as, the initial
	% insts of ModesA; and the final insts of ModesA specify at
	% least as much information as, and the same binding as, the
	% final insts of ModesB.  Any inst pairs in Expansions are assumed
	% to match_final each other.
	%
:- pred pred_inst_argmodes_matches(list(mode), instmap, list(mode), instmap,
		inst_table, module_info, expansions, alias_map, alias_map).
:- mode pred_inst_argmodes_matches(in, in, in, in, in, in, in, in, in)
		is semidet.

pred_inst_argmodes_matches([], _, [], _, _, _, _, _, _).
pred_inst_argmodes_matches([ModeA|ModeAs], InstMapA, [ModeB|ModeBs],
		InstMapB, InstTable, ModuleInfo, Expansions, AliasMapA0,
		AliasMapB0) :-
	mode_get_insts(ModuleInfo, ModeA, InitialA, FinalA),
	mode_get_insts(ModuleInfo, ModeB, InitialB, FinalB),
	inst_matches_final_2(InitialB, InstMapB, InitialA, InstMapA,
		InstTable, ModuleInfo, Expansions, no, AliasMapA0, AliasMapA1),
	inst_matches_final_2(FinalA, InstMapA, FinalB, InstMapB,
		InstTable, ModuleInfo, Expansions, no, AliasMapB0, AliasMapB1),
	pred_inst_argmodes_matches(ModeAs, InstMapA, ModeBs, InstMapB,
		InstTable, ModuleInfo, Expansions, AliasMapA1, AliasMapB1).

%-----------------------------------------------------------------------------%

unique_matches_initial(unique, _).
unique_matches_initial(mostly_unique, mostly_unique).
unique_matches_initial(mostly_unique, shared).
unique_matches_initial(mostly_unique, mostly_clobbered).
unique_matches_initial(mostly_unique, clobbered).
unique_matches_initial(shared, shared).
unique_matches_initial(shared, mostly_clobbered).
unique_matches_initial(shared, clobbered).
unique_matches_initial(mostly_clobbered, mostly_clobbered).
unique_matches_initial(mostly_clobbered, clobbered).
unique_matches_initial(clobbered, clobbered).

unique_matches_final(A, B) :-
	unique_matches_initial(A, B).

%-----------------------------------------------------------------------------%

:- pred bound_inst_list_matches_uniq(list(bound_inst), uniqueness,
				instmap, inst_table, module_info).
:- mode bound_inst_list_matches_uniq(in, in, in, in, in) is semidet.

bound_inst_list_matches_uniq(List, Uniq, InstMap, InstTable, ModuleInfo) :-
	( Uniq = unique ->
		bound_inst_list_is_unique(List, InstMap, InstTable,
				ModuleInfo)
	; Uniq = mostly_unique ->
		bound_inst_list_is_mostly_unique(List, InstMap, InstTable,
				ModuleInfo)
	;
		true
	).

:- pred uniq_matches_bound_inst_list(uniqueness, list(bound_inst),
				instmap, inst_table, module_info).
:- mode uniq_matches_bound_inst_list(in, in, in, in, in) is semidet.

uniq_matches_bound_inst_list(Uniq, List, InstMap, InstTable, ModuleInfo) :-
	( Uniq = shared ->
		bound_inst_list_is_not_partly_unique(List, InstMap,
				InstTable, ModuleInfo)
	; Uniq = mostly_unique ->
		bound_inst_list_is_not_fully_unique(List, InstMap,
				InstTable, ModuleInfo)
	;
		true
	).

%-----------------------------------------------------------------------------%

	% Here we check that the functors in the first list are a
	% subset of the functors in the second list. 
	% (If a bound(...) inst only specifies the insts for some of
	% the constructors of its type, then it implicitly means that
	% all other constructors must have all their arguments
	% `not_reached'.)
	% The code here makes use of the fact that the bound_inst lists
	% are sorted.

:- pred bound_inst_list_matches_initial(list(bound_inst), instmap,
		list(bound_inst), instmap, inst_table, module_info, expansions,
		bool, alias_map, alias_map).
:- mode bound_inst_list_matches_initial(in, in, in, in, in, in, in, in,
		in, out) is semidet.

bound_inst_list_matches_initial([], _, _, _, _, _, _, _, AM, AM).
bound_inst_list_matches_initial([X|Xs], InstMapA, [Y|Ys], InstMapB,
		InstTable, ModuleInfo, Expansions, IgnoreAliasing,
		AliasMap0, AliasMap) :-
	X = functor(ConsIdX, ArgsX),
	Y = functor(ConsIdY, ArgsY),
	( ConsIdX = ConsIdY ->
		inst_list_matches_initial(ArgsX, InstMapA, ArgsY, InstMapB,
				InstTable, ModuleInfo, Expansions,
				IgnoreAliasing, AliasMap0, AliasMap1),
		bound_inst_list_matches_initial(Xs, InstMapA, Ys, InstMapB,
				InstTable, ModuleInfo, Expansions,
				IgnoreAliasing, AliasMap1, AliasMap)
	;
		compare(>, ConsIdX, ConsIdY),
			% ConsIdY does not occur in [X|Xs].
			% Hence [X|Xs] implicitly specifies `not_reached'
			% for the args of ConsIdY, and hence 
			% automatically matches_initial Y.  We just need to
			% check that [X|Xs] matches_initial Ys.
		bound_inst_list_matches_initial([X|Xs], InstMapA, Ys,
				InstMapB, InstTable, ModuleInfo, Expansions,
				IgnoreAliasing, AliasMap0, AliasMap)
	).

:- pred inst_list_matches_initial(list(inst), instmap, list(inst), instmap,
	inst_table, module_info, expansions, bool, alias_map, alias_map).
:- mode inst_list_matches_initial(in, in, in, in, in, in, in, in, in, out)
	is semidet.

inst_list_matches_initial([], _, [], _, _, _, _, _, AM, AM).
inst_list_matches_initial([X|Xs], InstMapA, [Y|Ys], InstMapB, InstTable,
		ModuleInfo, Expansions, IgnoreAliasing, AliasMap0, AliasMap) :-
	inst_matches_initial_2(X, InstMapA, Y, InstMapB, InstTable,
			ModuleInfo, Expansions, IgnoreAliasing,
			AliasMap0, AliasMap1),
	inst_list_matches_initial(Xs, InstMapA, Ys, InstMapB, InstTable,
			ModuleInfo, Expansions, IgnoreAliasing,
			AliasMap1, AliasMap).

%-----------------------------------------------------------------------------%

	% inst_matches_aliasing(IgnoreAliasing, InstA, InstB,
	%		InstMapA, AliasMap0, AliasMap).
	% 	If we are not ignoring aliasing, compare the aliasing of two
	%	insts with respect to the current alias_map and update the
	%	alias_map to include new aliasing information.
	%	InstA must be at least as aliased as InstB for the predicate
	%	to succeed.
	%	InstMapA is the instmap associated with InstA.

:- pred inst_matches_aliasing(bool, inst, inst, instmap, alias_map, alias_map).
:- mode inst_matches_aliasing(in, in, in, in, in, out) is semidet.

inst_matches_aliasing(yes, _, _, _, AliasMap, AliasMap).
inst_matches_aliasing(no, InstA, InstB, InstMapA, AliasMap0, AliasMap) :-
	( InstB = alias(IKB) ->
		( map__search(AliasMap0, IKB, MaybeIK) ->
			% This inst_key has been seen before.
			% Check whether InstA has a matching alias.
			MaybeIK = yes(PrevIK),
			InstA = alias(IKA),
			instmap__inst_keys_are_equivalent(PrevIK, InstMapA,
				IKA, InstMapA),
			AliasMap = AliasMap0
		; InstA = alias(IKA) ->
			% Insert the new pair of corresponding inst_keys
			% into the alias_map.
			map__det_insert(AliasMap0, IKB, yes(IKA), AliasMap)
		;
			% Record that the new inst_key IKB has no corresponding
			% inst_key in InstA.  If alias(IKB) occurs a second
			% time, the predicate will fail.
			map__det_insert(AliasMap0, IKB, no, AliasMap)
		)
	;
		AliasMap = AliasMap0
	).

%-----------------------------------------------------------------------------%

inst_expand(InstMap, InstTable, ModuleInfo, Inst0, Inst) :-
	( Inst0 = defined_inst(InstName) ->
		inst_lookup(InstTable, ModuleInfo, InstName, Inst1),
		inst_expand(InstMap, InstTable, ModuleInfo, Inst1, Inst)
	; Inst0 = alias(InstKey) ->
		inst_table_get_inst_key_table(InstTable, IKT),
		instmap__inst_key_table_lookup(InstMap, IKT, InstKey, Inst1),
		inst_expand(InstMap, InstTable, ModuleInfo, Inst1, Inst)
	;
		Inst = Inst0
	).

inst_expand_defined_inst(InstTable, ModuleInfo, Inst0, Inst) :-
	( Inst0 = defined_inst(InstName) ->
		inst_lookup(InstTable, ModuleInfo, InstName, Inst1),
		inst_expand_defined_inst(InstTable, ModuleInfo, Inst1, Inst)
	;
		Inst = Inst0
	).

%-----------------------------------------------------------------------------%

inst_matches_final(InstA, InstMapA, InstB, InstMapB, InstTable, ModuleInfo,
		AliasMap0, AliasMap) :-
	set__init(Expansions),
	IgnoreAliasing = no,
	inst_matches_final_2(InstA, InstMapA, InstB, InstMapB, InstTable,
		ModuleInfo, Expansions, IgnoreAliasing, AliasMap0, AliasMap).

inst_matches_final_ignore_aliasing(InstA, InstMapA, InstB, InstMapB,
		InstTable, ModuleInfo) :-
	set__init(Expansions),
	map__init(AliasMap0),
	IgnoreAliasing = yes,
	inst_matches_final_2(InstA, InstMapA, InstB, InstMapB, InstTable,
		ModuleInfo, Expansions, IgnoreAliasing, AliasMap0, _AliasMap).

:- pred inst_matches_final_2(inst, instmap, inst, instmap, inst_table,
		module_info, expansions, bool, alias_map, alias_map).
:- mode inst_matches_final_2(in, in, in, in, in, in, in, in, in, out)
		is semidet.

inst_matches_final_2(InstA, InstMapA, InstB, InstMapB, InstTable,
		ModuleInfo, Expansions, IgnoreAliasing, AliasMap0, AliasMap) :-
	ThisExpansion = InstA - InstB,
	( set__member(ThisExpansion, Expansions) ->
		AliasMap = AliasMap0
	; InstA = InstB ->
		AliasMap = AliasMap0
	;
		inst_matches_aliasing(IgnoreAliasing, InstA, InstB,
			InstMapA, AliasMap0, AliasMap1),

		inst_expand(InstMapA, InstTable, ModuleInfo, InstA, InstA2),
		inst_expand(InstMapB, InstTable, ModuleInfo, InstB, InstB2),
		set__insert(Expansions, ThisExpansion, Expansions2),
		inst_matches_final_3(InstA2, InstMapA, InstB2, InstMapB,
			InstTable, ModuleInfo, Expansions2, IgnoreAliasing,
			AliasMap1, AliasMap)
	).

:- pred inst_matches_final_3(inst, instmap, inst, instmap, inst_table,
		module_info, expansions, bool, alias_map, alias_map).
:- mode inst_matches_final_3(in, in, in, in, in, in, in, in, in, out)
		is semidet.

inst_matches_final_3(any(UniqA), _, any(UniqB), _, _, _, _, _, AM, AM) :-
	unique_matches_final(UniqA, UniqB).
inst_matches_final_3(free(unique), _, any(Uniq), _, _, _, _, _, AM, AM) :-
	% We do not yet allow `free' to match `any',
	% unless the `any' is `clobbered_any' or `mostly_clobbered_any'.
	% Among other things, changing this would break compare_inst
	% in modecheck_call.m.
	( Uniq = clobbered ; Uniq = mostly_clobbered ).
inst_matches_final_3(free(Aliasing), _, free(Aliasing), _, _, _, _, _, AM, AM).
inst_matches_final_3(bound(UniqA, ListA), InstMapA, any(UniqB), _InstMapB,
		InstTable, ModuleInfo, _, _, AM, AM) :-
	unique_matches_final(UniqA, UniqB),
	bound_inst_list_matches_uniq(ListA, UniqB, InstMapA, InstTable,
			ModuleInfo),
	% We do not yet allow `free' to match `any'.
	% Among other things, changing this would break compare_inst
	% in modecheck_call.m.
	bound_inst_list_is_ground_or_any(ListA, InstMapA, InstTable,
			ModuleInfo).
inst_matches_final_3(bound(UniqA, ListA), InstMapA, bound(UniqB, ListB),
		InstMapB, InstTable, ModuleInfo, Expansions, IgnoreAliasing,
		AliasMap0, AliasMap) :-
	unique_matches_final(UniqA, UniqB),
	bound_inst_list_matches_final(ListA, InstMapA, ListB, InstMapB,
		InstTable, ModuleInfo, Expansions, IgnoreAliasing,
		AliasMap0, AliasMap).
inst_matches_final_3(bound(UniqA, ListA), InstMapA, ground(UniqB, no),
		_InstMapB, InstTable, ModuleInfo, _Exps, _, AM, AM) :-
	unique_matches_final(UniqA, UniqB),
	bound_inst_list_is_ground(ListA, InstMapA, InstTable, ModuleInfo),
	bound_inst_list_matches_uniq(ListA, UniqB, InstMapA, InstTable,
			ModuleInfo).
inst_matches_final_3(ground(UniqA, _), _, any(UniqB), _, _InstTable,
		_ModuleInfo, _Expansions, _, AM, AM) :-
	unique_matches_final(UniqA, UniqB).
inst_matches_final_3(ground(UniqA, _), _, bound(UniqB, ListB), InstMapB,
		InstTable, ModuleInfo, _Exps, _, AM, AM) :-
	unique_matches_final(UniqA, UniqB),
	uniq_matches_bound_inst_list(UniqA, ListB, InstMapB, InstTable,
			ModuleInfo).
		% XXX BUG! Should fail if there are not_reached
		% insts in ListB, or if ListB does not contain a complete list
		% of all the constructors for the type in question.
	%%% error("not implemented: `ground' matches_final `bound(...)'").
inst_matches_final_3(ground(UniqA, PredInstA), InstMapA,
		ground(UniqB, PredInstB), InstMapB,
		InstTable, ModuleInfo, Expansions, _, AM, AM) :-
	maybe_pred_inst_matches_final(PredInstA, InstMapA, PredInstB, InstMapB,
		InstTable, ModuleInfo, Expansions),
	unique_matches_final(UniqA, UniqB).
inst_matches_final_3(abstract_inst(_, _), _, any(shared), _, _, _, _, _,
		AM, AM).
inst_matches_final_3(abstract_inst(Name, ArgsA), InstMapA,
		abstract_inst(Name, ArgsB), InstMapB, InstTable, ModuleInfo,
		Expansions, IgnoreAliasing, AliasMap0, AliasMap) :-
	inst_list_matches_final(ArgsA, InstMapA, ArgsB, InstMapB, InstTable,
		ModuleInfo, Expansions, IgnoreAliasing,AliasMap0, AliasMap).
inst_matches_final_3(not_reached, _, _, _, _, _, _, _, AM, AM).

:- pred maybe_pred_inst_matches_final(maybe(pred_inst_info), instmap,
	maybe(pred_inst_info), instmap, inst_table, module_info, expansions).
:- mode maybe_pred_inst_matches_final(in, in, in, in, in, in, in) is semidet.

maybe_pred_inst_matches_final(no, _, no, _, _, _, _).
maybe_pred_inst_matches_final(yes(_), _, no, _, _, _, _).
maybe_pred_inst_matches_final(yes(PredInstA), InstMapA, yes(PredInstB),
		InstMapB, InstTable, ModuleInfo, Expansions) :-
	pred_inst_matches_2(PredInstA, InstMapA, PredInstB, InstMapB,
			InstTable, ModuleInfo, Expansions).

:- pred inst_list_matches_final(list(inst), instmap, list(inst), instmap,
	inst_table, module_info, expansions, bool, alias_map, alias_map).
:- mode inst_list_matches_final(in, in, in, in, in, in, in, in, in, out)
	is semidet.

inst_list_matches_final([], _, [], _, _, _ModuleInfo, _, _, AM, AM).
inst_list_matches_final([ArgA | ArgsA], InstMapA, [ArgB | ArgsB], InstMapB,
		InstTable, ModuleInfo, Expansions, IgnoreAliasing,
		AliasMap0, AliasMap) :-
	inst_matches_final_2(ArgA, InstMapA, ArgB, InstMapB, InstTable,
			ModuleInfo, Expansions, IgnoreAliasing,
			AliasMap0, AliasMap1),
	inst_list_matches_final(ArgsA, InstMapA, ArgsB, InstMapB, InstTable,
			ModuleInfo, Expansions, IgnoreAliasing,
			AliasMap1, AliasMap).

	% Here we check that the functors in the first list are a
	% subset of the functors in the second list. 
	% (If a bound(...) inst only specifies the insts for some of
	% the constructors of its type, then it implicitly means that
	% all other constructors must have all their arguments
	% `not_reached'.)
	% The code here makes use of the fact that the bound_inst lists
	% are sorted.

:- pred bound_inst_list_matches_final(list(bound_inst), instmap,
	list(bound_inst), instmap, inst_table, module_info, expansions,
	bool, alias_map, alias_map).
:- mode bound_inst_list_matches_final(in, in, in, in, in, in, in, in, in, out)
	is semidet.

bound_inst_list_matches_final([], _, _, _, _, _, _, _, AM, AM).
bound_inst_list_matches_final([X|Xs], InstMapA, [Y|Ys], InstMapB, InstTable,
		ModuleInfo, Expansions, IgnoreAliasing, AliasMap0, AliasMap) :-
	X = functor(ConsIdX, ArgsX),
	Y = functor(ConsIdY, ArgsY),
	( ConsIdX = ConsIdY ->
		inst_list_matches_final(ArgsX, InstMapA, ArgsY, InstMapB,
			InstTable, ModuleInfo, Expansions, IgnoreAliasing,
			AliasMap0, AliasMap1),
		bound_inst_list_matches_final(Xs, InstMapA, Ys, InstMapB,
			InstTable, ModuleInfo, Expansions, IgnoreAliasing,
			AliasMap1, AliasMap)
	;
		compare(>, ConsIdX, ConsIdY),
			% ConsIdY does not occur in [X|Xs].
			% Hence [X|Xs] implicitly specifies `not_reached'
			% for the args of ConsIdY, and hence 
			% automatically matches_final Y.  We just need to
			% check that [X|Xs] matches_final Ys.
		bound_inst_list_matches_final([X|Xs], InstMapA, Ys, InstMapB,
			InstTable, ModuleInfo, Expansions, IgnoreAliasing,
			AliasMap0, AliasMap)
	).

inst_matches_binding(InstA, InstMapA, InstB, InstMapB, InstTable, ModuleInfo) :-
	set__init(Expansions),
	inst_matches_binding_2(InstA, InstMapA, InstB, InstMapB, InstTable,
			ModuleInfo, Expansions).

:- pred inst_matches_binding_2(inst, instmap, inst, instmap, inst_table,
		module_info, expansions).
:- mode inst_matches_binding_2(in, in, in, in, in, in, in) is semidet.

inst_matches_binding_2(InstA, InstMapA, InstB, InstMapB, InstTable,
		ModuleInfo, Expansions) :-
	ThisExpansion = InstA - InstB,
	( set__member(ThisExpansion, Expansions) ->
		true
	;
		inst_expand(InstMapA, InstTable, ModuleInfo, InstA, InstA2),
		inst_expand(InstMapB, InstTable, ModuleInfo, InstB, InstB2),
		set__insert(Expansions, ThisExpansion, Expansions2),
		inst_matches_binding_3(InstA2, InstMapA, InstB2, InstMapB,
			InstTable, ModuleInfo, Expansions2)
	).

:- pred inst_matches_binding_3(inst, instmap, inst, instmap, inst_table,
		module_info, expansions).
:- mode inst_matches_binding_3(in, in, in, in, in, in, in) is semidet.

% Note that `any' is *not* considered to match `any'.
inst_matches_binding_3(free(Aliasing), _, free(Aliasing), _, _, _, _).
inst_matches_binding_3(bound(_UniqA, ListA), InstMapA, bound(_UniqB, ListB),
		InstMapB, InstTable, ModuleInfo, Expansions) :-
	bound_inst_list_matches_binding(ListA, InstMapA, ListB, InstMapB,
		InstTable, ModuleInfo, Expansions).
inst_matches_binding_3(bound(_UniqA, ListA), InstMapA, ground(_UniqB, no),
			_InstMapB, InstTable, ModuleInfo, _Exps) :-
	bound_inst_list_is_ground(ListA, InstMapA, InstTable, ModuleInfo).
inst_matches_binding_3(ground(_UniqA, _), _InstMapA, bound(_UniqB, ListB),
			InstMapB, InstTable,
			ModuleInfo, _Exps) :-
	bound_inst_list_is_ground(ListB, InstMapB, InstTable, ModuleInfo).
		% XXX BUG! Should fail if there are not_reached
		% insts in ListB, or if ListB does not contain a complete list
		% of all the constructors for the type in question.
	%%% error("not implemented: `ground' matches_binding `bound(...)'").
inst_matches_binding_3(ground(_UniqA, PredInstA), InstMapA,
		ground(_UniqB, PredInstB), InstMapB, InstTable, ModuleInfo,
		_) :-
	pred_inst_matches_binding(PredInstA, InstMapA, PredInstB, InstMapB,
		InstTable, ModuleInfo).
inst_matches_binding_3(abstract_inst(Name, ArgsA), InstMapA,
		abstract_inst(Name, ArgsB), InstMapB, InstTable, ModuleInfo,
		Expansions) :-
	inst_list_matches_binding(ArgsA, InstMapA, ArgsB, InstMapB, InstTable,
		ModuleInfo, Expansions).
inst_matches_binding_3(not_reached, _, _, _, _, _, _).

:- pred pred_inst_matches_binding(maybe(pred_inst_info), instmap,
		maybe(pred_inst_info), instmap, inst_table, module_info).
:- mode pred_inst_matches_binding(in, in, in, in, in, in) is semidet.

pred_inst_matches_binding(no, _, no, _, _, _).
pred_inst_matches_binding(yes(_), _, no, _, _, _).
pred_inst_matches_binding(yes(PredInstA), InstMapA, yes(PredInstB), InstMapB,
		InstTable, ModuleInfo) :-
	pred_inst_matches(PredInstA, InstMapA, PredInstB, InstMapB,
		InstTable, ModuleInfo).

:- pred inst_list_matches_binding(list(inst), instmap, list(inst), instmap,
		inst_table, module_info, expansions).
:- mode inst_list_matches_binding(in, in, in, in, in, in, in) is semidet.

inst_list_matches_binding([], _, [], _, _InstTable, _ModuleInfo, _).
inst_list_matches_binding([ArgA | ArgsA], InstMapA, [ArgB | ArgsB], InstMapB,
			InstTable, ModuleInfo, Expansions) :-
	inst_matches_binding_2(ArgA, InstMapA, ArgB, InstMapB, InstTable,
			ModuleInfo, Expansions),
	inst_list_matches_binding(ArgsA, InstMapA, ArgsB, InstMapB,
			InstTable, ModuleInfo, Expansions).

	% Here we check that the functors in the first list are a
	% subset of the functors in the second list. 
	% (If a bound(...) inst only specifies the insts for some of
	% the constructors of its type, then it implicitly means that
	% all other constructors must have all their arguments
	% `not_reached'.)
	% The code here makes use of the fact that the bound_inst lists
	% are sorted.

:- pred bound_inst_list_matches_binding(list(bound_inst), instmap,
	list(bound_inst), instmap, inst_table, module_info, expansions).
:- mode bound_inst_list_matches_binding(in, in, in, in, in, in, in) is semidet.

bound_inst_list_matches_binding([], _, _, _, _, _, _).
bound_inst_list_matches_binding([X|Xs], InstMapA, [Y|Ys], InstMapB,
		InstTable, ModuleInfo, Expansions) :-
	X = functor(ConsIdX, ArgsX),
	Y = functor(ConsIdY, ArgsY),
	( ConsIdX = ConsIdY ->
		inst_list_matches_binding(ArgsX, InstMapA, ArgsY, InstMapB,
				InstTable, ModuleInfo, Expansions),
		bound_inst_list_matches_binding(Xs, InstMapA, Ys, InstMapB,
				InstTable, ModuleInfo, Expansions)
	;
		compare(>, ConsIdX, ConsIdY),
			% ConsIdX does not occur in [X|Xs].
			% Hence [X|Xs] implicitly specifies `not_reached'
			% for the args of ConsIdY, and hence 
			% automatically matches_binding Y.  We just need to
			% check that [X|Xs] matches_binding Ys.
		bound_inst_list_matches_binding([X|Xs], InstMapA, Ys, InstMapB,
			InstTable, ModuleInfo, Expansions)
	).

%-----------------------------------------------------------------------------%

:- type inst_property == pred(inst, instmap, inst_table, module_info,
		set(inst)).
:- inst inst_property = (pred(in, in, in, in, in) is semidet).

	% inst_is_clobbered succeeds iff the inst passed is `clobbered'
	% or `mostly_clobbered' or if it is a user-defined inst which
	% is defined as one of those.

inst_is_clobbered(not_reached, _, _, _) :- fail.
inst_is_clobbered(any(mostly_clobbered), _, _, _).
inst_is_clobbered(any(clobbered), _, _, _).
inst_is_clobbered(ground(clobbered, _), _, _, _).
inst_is_clobbered(ground(mostly_clobbered, _), _, _, _).
inst_is_clobbered(bound(clobbered, _), _, _, _).
inst_is_clobbered(bound(mostly_clobbered, _), _, _, _).
inst_is_clobbered(inst_var(_), _, _, _) :-
	error("internal error: uninstantiated inst parameter").
inst_is_clobbered(defined_inst(InstName), InstMap, InstTable, ModuleInfo) :-
	inst_lookup(InstTable, ModuleInfo, InstName, Inst),
	inst_is_clobbered(Inst, InstMap, InstTable, ModuleInfo).
inst_is_clobbered(alias(Key), InstMap, InstTable, ModuleInfo) :-
	inst_table_get_inst_key_table(InstTable, IKT),
	instmap__inst_key_table_lookup(InstMap, IKT, Key, Inst),
	inst_is_clobbered(Inst, InstMap, InstTable, ModuleInfo).


	% inst_is_free succeeds iff the inst passed is `free'
	% or is a user-defined inst which is defined as `free'.
	% Abstract insts must not be free.

inst_is_free(free(_), _, _, _).
inst_is_free(free(_, _), _, _, _).
inst_is_free(inst_var(_), _, _, _) :-
	error("internal error: uninstantiated inst parameter").
inst_is_free(defined_inst(InstName), InstMap, InstTable, ModuleInfo) :-
	inst_lookup(InstTable, ModuleInfo, InstName, Inst),
	inst_is_free(Inst, InstMap, InstTable, ModuleInfo).
inst_is_free(alias(Key), InstMap, InstTable, ModuleInfo) :-
	inst_table_get_inst_key_table(InstTable, IKT),
	instmap__inst_key_table_lookup(InstMap, IKT, Key, Inst),
	inst_is_free(Inst, InstMap, InstTable, ModuleInfo).

	% inst_is_free_alias succeeds iff the inst passed is `free(alias)'
	% or a user-defined inst which is defined as `free(alias)' or
	% `alias(IK)' where `IK' points to a `free(alias)' inst in the IKT.

inst_is_free_alias(free(alias), _, _, _).
inst_is_free_alias(free(alias, _), _, _, _).
inst_is_free_alias(inst_var(_), _, _, _) :-
	error("internal error: uninstantiated inst parameter").
inst_is_free_alias(defined_inst(InstName), InstMap, InstTable, ModuleInfo) :-
	inst_lookup(InstTable, ModuleInfo, InstName, Inst),
	inst_is_free_alias(Inst, InstMap, InstTable, ModuleInfo).
inst_is_free_alias(alias(Key), InstMap, InstTable, ModuleInfo) :-
	inst_table_get_inst_key_table(InstTable, IKT),
	instmap__inst_key_table_lookup(InstMap, IKT, Key, Inst),
	inst_is_free_alias(Inst, InstMap, InstTable, ModuleInfo).

	% inst_contains_free_alias succeeds iff the inst passed is free(alias)
	% or is bound to a functor with an argument containing a free(alias).
inst_contains_free_alias(Inst, InstMap, InstTable, ModuleInfo) :-
	set__init(Seen0),
	inst_contains_free_alias_2(Inst, InstMap, InstTable, ModuleInfo, Seen0).

:- pred inst_contains_free_alias_2(inst, instmap, inst_table, module_info,
	set(inst_name)).
:- mode inst_contains_free_alias_2(in, in, in, in, in) is semidet.

inst_contains_free_alias_2(free(alias), _, _, _, _).
inst_contains_free_alias_2(free(alias, _), _, _, _, _).
inst_contains_free_alias_2(inst_var(_), _, _, _, _) :-
        error("internal error: uninstantiated inst parameter").
inst_contains_free_alias_2(defined_inst(InstName), InstMap, InstTable,
		ModuleInfo, Seen0) :-
	\+ set__member(InstName, Seen0),
	inst_lookup(InstTable, ModuleInfo, InstName, Inst),
	set__insert(Seen0, InstName, Seen1),
	inst_contains_free_alias_2(Inst, InstMap, InstTable, ModuleInfo, Seen1).
inst_contains_free_alias_2(alias(Key), InstMap, InstTable, ModuleInfo, Seen) :-
	inst_table_get_inst_key_table(InstTable, IKT),
	instmap__inst_key_table_lookup(InstMap, IKT, Key, Inst),
	inst_contains_free_alias_2(Inst, InstMap, InstTable, ModuleInfo, Seen).
inst_contains_free_alias_2(bound(_, BoundInsts), InstMap, InstTable,
		ModuleInfo, Seen) :-
	list__member(functor(_, ArgInsts), BoundInsts),
	list__member(Inst, ArgInsts),
	inst_contains_free_alias_2(Inst, InstMap, InstTable, ModuleInfo, Seen).

	% inst_is_bound succeeds iff the inst passed is not `free'
	% or is a user-defined inst which is not defined as `free'.
	% Abstract insts must be bound.

inst_is_bound(not_reached, _, _, _).
inst_is_bound(any(_), _, _, _).
inst_is_bound(ground(_, _), _, _, _).
inst_is_bound(bound(_, _), _, _, _).
inst_is_bound(inst_var(_), _, _, _) :-
	error("internal error: uninstantiated inst parameter").
inst_is_bound(defined_inst(InstName), InstMap, InstTable, ModuleInfo) :-
	inst_lookup(InstTable, ModuleInfo, InstName, Inst),
	inst_is_bound(Inst, InstMap, InstTable, ModuleInfo).
inst_is_bound(abstract_inst(_, _), _, _, _).
inst_is_bound(alias(Key), InstMap, InstTable, ModuleInfo) :-
	inst_table_get_inst_key_table(InstTable, IKT),
	instmap__inst_key_table_lookup(InstMap, IKT, Key, Inst),
	inst_is_bound(Inst, InstMap, InstTable, ModuleInfo).

	% inst_is_bound_to_functors succeeds iff the inst passed is
	% `bound(_Uniq, Functors)' or is a user-defined inst which expands to
	% `bound(_Uniq, Functors)'.

inst_is_bound_to_functors(bound(_Uniq, Functors), _, _, _, Functors).
inst_is_bound_to_functors(inst_var(_), _, _, _, _) :-
	error("internal error: uninstantiated inst parameter").
inst_is_bound_to_functors(defined_inst(InstName), InstMap, InstTable,
			ModuleInfo, Functors) :-
	inst_lookup(InstTable, ModuleInfo, InstName, Inst),
	inst_is_bound_to_functors(Inst, InstMap, InstTable, ModuleInfo,
			Functors).
inst_is_bound_to_functors(alias(Key), InstMap, InstTable, ModuleInfo,
			Functors) :-
	inst_table_get_inst_key_table(InstTable, IKT),
	instmap__inst_key_table_lookup(InstMap, IKT, Key, Inst),
	inst_is_bound_to_functors(Inst, InstMap, InstTable, ModuleInfo,
			Functors).

%-----------------------------------------------------------------------------%

	% inst_is_ground succeeds iff the inst passed is `ground'
	% or the equivalent.  Abstract insts are not considered ground.

inst_is_ground(Inst, InstMap, InstTable, ModuleInfo) :-
	set__init(Expansions),
	inst_is_ground_2(Inst, InstMap, InstTable, ModuleInfo, Expansions).

	% The fourth arg is the set of insts which have already
	% been expanded - we use this to avoid going into an
	% infinite loop.

:- pred inst_is_ground_2(inst, instmap, inst_table, module_info, set(inst)).
:- mode inst_is_ground_2(in, in, in, in, in) is semidet.

inst_is_ground_2(not_reached, _, _, _, _).
inst_is_ground_2(bound(_, List), InstMap, InstTable, ModuleInfo,
		Expansions) :-
	bound_inst_list_has_property(inst_is_ground_2, List, InstMap,
		InstTable, ModuleInfo, Expansions).
inst_is_ground_2(ground(_, _), _, _, _, _).
inst_is_ground_2(inst_var(_), _, _, _, _) :-
	error("internal error: uninstantiated inst parameter").
inst_is_ground_2(Inst, InstMap, InstTable, ModuleInfo, Expansions) :-
	Inst = defined_inst(InstName),
	( set__member(Inst, Expansions) ->
		true
	;
		set__insert(Expansions, Inst, Expansions2),
		inst_lookup(InstTable, ModuleInfo, InstName, Inst2),
		inst_is_ground_2(Inst2, InstMap, InstTable, ModuleInfo,
				Expansions2)
	).
inst_is_ground_2(alias(Key), InstMap, InstTable, ModuleInfo, Expansions) :-
	inst_table_get_inst_key_table(InstTable, IKT),
	instmap__inst_key_table_lookup(InstMap, IKT, Key, Inst),
	inst_is_ground_2(Inst, InstMap, InstTable, ModuleInfo, Expansions).

	% inst_is_ground_or_any succeeds iff the inst passed is `ground',
	% `any', or the equivalent.  Fails for abstract insts.

inst_is_ground_or_any(Inst, InstMap, InstTable, ModuleInfo) :-
	set__init(Expansions),
	inst_is_ground_or_any_2(Inst, InstMap, InstTable, ModuleInfo,
			Expansions).

	% The fourth arg is the set of insts which have already
	% been expanded - we use this to avoid going into an
	% infinite loop.

:- pred inst_is_ground_or_any_2(inst, instmap, inst_table, module_info,
			set(inst)).
:- mode inst_is_ground_or_any_2(in, in, in, in, in) is semidet.

inst_is_ground_or_any_2(not_reached, _, _, _, _).
inst_is_ground_or_any_2(bound(_, List), InstMap, InstTable, ModuleInfo,
		Expansions) :-
	bound_inst_list_has_property(inst_is_ground_or_any_2, List, InstMap,
		InstTable, ModuleInfo, Expansions).
inst_is_ground_or_any_2(ground(_, _), _, _, _, _).
inst_is_ground_or_any_2(any(_), _, _, _, _).
inst_is_ground_or_any_2(inst_var(_), _, _, _, _) :-
	error("internal error: uninstantiated inst parameter").
inst_is_ground_or_any_2(Inst, InstMap, InstTable, ModuleInfo, Expansions) :-
	Inst = defined_inst(InstName),
	( set__member(Inst, Expansions) ->
		true
	;
		set__insert(Expansions, Inst, Expansions2),
		inst_lookup(InstTable, ModuleInfo, InstName, Inst2),
		inst_is_ground_or_any_2(Inst2, InstMap, InstTable, ModuleInfo,
				Expansions2)
	).
inst_is_ground_or_any_2(alias(Key), InstMap, InstTable, ModuleInfo,
		Expansions) :-
	inst_table_get_inst_key_table(InstTable, IKT),
	instmap__inst_key_table_lookup(InstMap, IKT, Key, Inst),
	inst_is_ground_or_any_2(Inst, InstMap, InstTable, ModuleInfo,
		Expansions).

	% inst_is_higher_order_ground succeeds iff the inst passed is `ground'
	% or equivalent and has a pred_inst_info.

inst_is_higher_order_ground(ground(_, yes(_PredInstInfo)), _, _, _).
inst_is_higher_order_ground(inst_var(_), _, _, _) :-
	error("internal error: uninstantiated inst parameter").
inst_is_higher_order_ground(Inst, InstMap, InstTable, ModuleInfo) :-
	Inst = defined_inst(InstName),
	inst_lookup(InstTable, ModuleInfo, InstName, Inst2),
	inst_is_higher_order_ground(Inst2, InstMap, InstTable, ModuleInfo).
inst_is_higher_order_ground(alias(Key), InstMap, InstTable, ModuleInfo) :-
	inst_table_get_inst_key_table(InstTable, IKT),
	instmap__inst_key_table_lookup(InstMap, IKT, Key, Inst),
	inst_is_higher_order_ground(Inst, InstMap, InstTable, ModuleInfo).

	% inst_is_unique succeeds iff the inst passed is unique
	% or free.  Abstract insts are not considered unique.

inst_is_unique(Inst, InstMap, InstTable, ModuleInfo) :-
	set__init(Expansions),
	inst_is_unique_2(Inst, InstMap, InstTable, ModuleInfo, Expansions).

	% The fifth arg is the set of insts which have already
	% been expanded - we use this to avoid going into an
	% infinite loop.

:- pred inst_is_unique_2(inst, instmap, inst_table, module_info, set(inst)).
:- mode inst_is_unique_2(in, in, in, in, in) is semidet.

inst_is_unique_2(not_reached, _, _, _, _).
inst_is_unique_2(bound(unique, List), InstMap, InstTable, ModuleInfo,
			Expansions) :-
	bound_inst_list_has_property(inst_is_unique_2, List, InstMap,
			InstTable, ModuleInfo, Expansions).
inst_is_unique_2(any(unique), _, _, _, _).
inst_is_unique_2(free(_), _, _, _, _).
inst_is_unique_2(free(_,_), _, _, _, _).
inst_is_unique_2(ground(unique, _), _, _, _, _).
inst_is_unique_2(inst_var(_), _, _, _, _) :-
	error("internal error: uninstantiated inst parameter").
inst_is_unique_2(Inst, InstMap, InstTable, ModuleInfo, Expansions) :-
	Inst = defined_inst(InstName),
	( set__member(Inst, Expansions) ->
		true
	;
		set__insert(Expansions, Inst, Expansions2),
		inst_lookup(InstTable, ModuleInfo, InstName, Inst2),
		inst_is_unique_2(Inst2, InstMap, InstTable, ModuleInfo,
				Expansions2)
	).
inst_is_unique_2(alias(Key), InstMap, InstTable, ModuleInfo, Expansions) :-
	inst_table_get_inst_key_table(InstTable, IKT),
	instmap__inst_key_table_lookup(InstMap, IKT, Key, Inst),
	inst_is_unique_2(Inst, InstMap, InstTable, ModuleInfo, Expansions).

	% inst_is_mostly_unique succeeds iff the inst passed is unique,
	% mostly_unique, or free.  Abstract insts are not considered unique.

inst_is_mostly_unique(Inst, InstMap, InstTable, ModuleInfo) :-
	set__init(Expansions),
	inst_is_mostly_unique_2(Inst, InstMap, InstTable, ModuleInfo,
			Expansions).

	% The fourth arg is the set of insts which have already
	% been expanded - we use this to avoid going into an
	% infinite loop.

:- pred inst_is_mostly_unique_2(inst, instmap, inst_table, module_info,
		set(inst)).
:- mode inst_is_mostly_unique_2(in, in, in, in, in) is semidet.

inst_is_mostly_unique_2(not_reached, _, _, _, _).
inst_is_mostly_unique_2(bound(mostly_unique, List), InstMap, InstTable,
		ModuleInfo, Expansions) :-
	bound_inst_list_has_property(inst_is_mostly_unique_2, List, InstMap,
		InstTable, ModuleInfo, Expansions).
inst_is_mostly_unique_2(any(unique), _, _, _, _).
inst_is_mostly_unique_2(any(mostly_unique), _, _, _, _).
inst_is_mostly_unique_2(free(_), _, _, _, _).
inst_is_mostly_unique_2(free(_, _), _, _, _, _).
inst_is_mostly_unique_2(ground(unique, _), _, _, _, _).
inst_is_mostly_unique_2(ground(mostly_unique, _), _, _, _, _).
inst_is_mostly_unique_2(inst_var(_), _, _, _, _) :-
	error("internal error: uninstantiated inst parameter").
inst_is_mostly_unique_2(Inst, InstMap, InstTable, ModuleInfo, Expansions) :-
	Inst = defined_inst(InstName),
	( set__member(Inst, Expansions) ->
		true
	;
		set__insert(Expansions, Inst, Expansions2),
		inst_lookup(InstTable, ModuleInfo, InstName, Inst2),
		inst_is_mostly_unique_2(Inst2, InstMap, InstTable, ModuleInfo,
				Expansions2)
	).
inst_is_mostly_unique_2(alias(Key), InstMap, InstTable, ModuleInfo,
		Expansions) :-
	inst_table_get_inst_key_table(InstTable, IKT),
	instmap__inst_key_table_lookup(InstMap, IKT, Key, Inst),
	inst_is_mostly_unique_2(Inst, InstMap, InstTable, ModuleInfo,
		Expansions).

	% inst_is_not_partly_unique succeeds iff the inst passed is
	% not unique or mostly_unique, i.e. if it is shared
	% or free.  It fails for abstract insts.

inst_is_not_partly_unique(Inst, InstMap, InstTable, ModuleInfo) :-
	set__init(Expansions),
	inst_is_not_partly_unique_2(Inst, InstMap, InstTable, ModuleInfo,
			Expansions).

	% The fourth arg is the set of insts which have already
	% been expanded - we use this to avoid going into an
	% infinite loop.

:- pred inst_is_not_partly_unique_2(inst, instmap, inst_table, module_info,
		set(inst)).
:- mode inst_is_not_partly_unique_2(in, in, in, in, in) is semidet.

inst_is_not_partly_unique_2(not_reached, _, _, _, _).
inst_is_not_partly_unique_2(bound(shared, List), InstMap, InstTable,
		ModuleInfo, Expansions) :-
	bound_inst_list_has_property(inst_is_not_partly_unique_2, List,
		InstMap, InstTable, ModuleInfo, Expansions).
inst_is_not_partly_unique_2(free(_), _, _, _, _).
inst_is_not_partly_unique_2(free(_,_), _, _, _, _).
inst_is_not_partly_unique_2(any(shared), _, _, _, _).
inst_is_not_partly_unique_2(ground(shared, _), _, _, _, _).
inst_is_not_partly_unique_2(inst_var(_), _, _, _, _) :-
	error("internal error: uninstantiated inst parameter").
inst_is_not_partly_unique_2(Inst, InstMap, InstTable, ModuleInfo, Expansions) :-
	Inst = defined_inst(InstName),
	( set__member(Inst, Expansions) ->
		true
	;
		set__insert(Expansions, Inst, Expansions2),
		inst_lookup(InstTable, ModuleInfo, InstName, Inst2),
		inst_is_not_partly_unique_2(Inst2, InstMap, InstTable,
			ModuleInfo, Expansions2)
	).
inst_is_not_partly_unique_2(alias(Key), InstMap, InstTable, ModuleInfo,
		Expansions) :-
	inst_table_get_inst_key_table(InstTable, IKT),
	instmap__inst_key_table_lookup(InstMap, IKT, Key, Inst),
	inst_is_not_partly_unique_2(Inst, InstMap, InstTable, ModuleInfo,
		Expansions).

	% inst_is_not_fully_unique succeeds iff the inst passed is
	% not unique, i.e. if it is mostly_unique, shared,
	% or free.  It fails for abstract insts.

inst_is_not_fully_unique(Inst, InstMap, InstTable, ModuleInfo) :-
	set__init(Expansions),
	inst_is_not_fully_unique_2(Inst, InstMap, InstTable, ModuleInfo,
			Expansions).

	% The fourth arg is the set of insts which have already
	% been expanded - we use this to avoid going into an
	% infinite loop.

:- pred inst_is_not_fully_unique_2(inst, instmap, inst_table, module_info,
		set(inst)).
:- mode inst_is_not_fully_unique_2(in, in, in, in, in) is semidet.

inst_is_not_fully_unique_2(not_reached, _, _, _, _).
inst_is_not_fully_unique_2(bound(shared, List), InstMap, InstTable, ModuleInfo,
		Expansions) :-
	bound_inst_list_has_property(inst_is_not_fully_unique_2, List,
		InstMap, InstTable, ModuleInfo, Expansions).
inst_is_not_fully_unique_2(bound(mostly_unique, List), InstMap, InstTable,
		ModuleInfo, Expansions) :-
	bound_inst_list_has_property(inst_is_not_fully_unique_2, List,
		InstMap, InstTable, ModuleInfo, Expansions).
inst_is_not_fully_unique_2(any(shared), _, _, _, _).
inst_is_not_fully_unique_2(any(mostly_unique), _, _, _, _).
inst_is_not_fully_unique_2(free(_), _, _, _, _).
inst_is_not_fully_unique_2(free(_,_), _, _, _, _).
inst_is_not_fully_unique_2(ground(shared, _), _, _, _, _).
inst_is_not_fully_unique_2(ground(mostly_unique, _), _, _, _, _).
inst_is_not_fully_unique_2(inst_var(_), _, _, _, _) :-
	error("internal error: uninstantiated inst parameter").
inst_is_not_fully_unique_2(Inst, InstMap, InstTable, ModuleInfo, Expansions) :-
	Inst = defined_inst(InstName),
	( set__member(Inst, Expansions) ->
		true
	;
		set__insert(Expansions, Inst, Expansions2),
		inst_lookup(InstTable, ModuleInfo, InstName, Inst2),
		inst_is_not_fully_unique_2(Inst2, InstMap, InstTable,
				ModuleInfo, Expansions2)
	).
inst_is_not_fully_unique_2(alias(Key), InstMap, InstTable, ModuleInfo,
		Expansions) :-
	inst_table_get_inst_key_table(InstTable, IKT),
	instmap__inst_key_table_lookup(InstMap, IKT, Key, Inst),
	inst_is_not_fully_unique_2(Inst, InstMap, InstTable, ModuleInfo,
			Expansions).

%-----------------------------------------------------------------------------%

:- pred bound_inst_list_has_property(inst_property, list(bound_inst),
		instmap, inst_table, module_info, set(inst)).
:- mode bound_inst_list_has_property(in(inst_property), in, in, in, in, in)
		is semidet.

bound_inst_list_has_property(_, [], _, _, _, _).
bound_inst_list_has_property(Property, [functor(_Name, Args) | BoundInsts],
		InstMap, InstTable, ModuleInfo, Expansions) :-
	inst_list_has_property(Property, Args, InstMap, InstTable, ModuleInfo,
		Expansions),
	bound_inst_list_has_property(Property, BoundInsts, InstMap, InstTable,
		ModuleInfo, Expansions).
% bound_inst_list_has_property(Property, [functor(_Name, Args) | BoundInsts],
% 		InstMap, InstTable, ModuleInfo, Expansions) :-
% 	all [Args] (
% 		list__member(functor(_Name, Args), BoundInsts)
% 	=>
% 		inst_list_has_property(Property, BoundInsts, InstMap,
% 			InstTable, ModuleInfo, Expansions)
% 	).

bound_inst_list_is_ground(BoundInsts, InstMap, InstTable, ModuleInfo) :-
	set__init(Expansions),
	bound_inst_list_has_property(inst_is_ground_2, BoundInsts, InstMap,
		InstTable, ModuleInfo, Expansions).

bound_inst_list_is_ground_or_any(BoundInsts, InstMap, InstTable, ModuleInfo) :-
	set__init(Expansions),
	bound_inst_list_has_property(inst_is_ground_or_any_2, BoundInsts,
		InstMap, InstTable, ModuleInfo, Expansions).

bound_inst_list_is_unique(BoundInsts, InstMap, InstTable, ModuleInfo) :-
	set__init(Expansions),
	bound_inst_list_has_property(inst_is_unique_2, BoundInsts, InstMap,
		InstTable, ModuleInfo, Expansions).

bound_inst_list_is_mostly_unique(BoundInsts, InstMap, InstTable, ModuleInfo) :-
	set__init(Expansions),
	bound_inst_list_has_property(inst_is_mostly_unique_2, BoundInsts,
		InstMap, InstTable, ModuleInfo, Expansions).

bound_inst_list_is_not_partly_unique(BoundInsts, InstMap, InstTable,
		ModuleInfo) :-
	set__init(Expansions),
	bound_inst_list_has_property(inst_is_not_partly_unique_2, BoundInsts,
		InstMap, InstTable, ModuleInfo, Expansions).

bound_inst_list_is_not_fully_unique(BoundInsts, InstMap, InstTable,
		ModuleInfo) :-
	set__init(Expansions),
	bound_inst_list_has_property(inst_is_not_fully_unique_2, BoundInsts,
		InstMap, InstTable, ModuleInfo, Expansions).

%-----------------------------------------------------------------------------%

:- pred inst_list_has_property(inst_property, list(inst), instmap,
		inst_table, module_info, set(inst)).
:- mode inst_list_has_property(in(inst_property), in, in, in, in, in)
		is semidet.

inst_list_has_property(_Property, [], _InstMap, _InstTable, _ModuleInfo,
		_Expansions).
inst_list_has_property(Property, [Inst | Insts], InstMap, InstTable,
		ModuleInfo, Expansions) :-
	call(Property, Inst, InstMap, InstTable, ModuleInfo, Expansions),
	inst_list_has_property(Property, Insts, InstMap, InstTable,
		ModuleInfo, Expansions).
% inst_list_has_property(Property, Insts, ModuleInfo, Expansions) :-
% 	all [Inst] (
% 		list__member(Inst, Insts)
% 	=>
% 		call(Property, Inst, InstTable, ModuleInfo, Expansions)
% 	).

inst_list_is_ground(Insts, InstMap, InstTable, ModuleInfo) :-
	set__init(Expansions),
	inst_list_has_property(inst_is_ground_2, Insts, InstMap, InstTable,
			ModuleInfo, Expansions).

inst_list_is_ground_or_any(Insts, InstMap, InstTable, ModuleInfo) :-
	set__init(Expansions),
	inst_list_has_property(inst_is_ground_or_any_2, Insts, InstMap,
			InstTable, ModuleInfo, Expansions).

inst_list_is_unique(Insts, InstMap, InstTable, ModuleInfo) :-
	set__init(Expansions),
	inst_list_has_property(inst_is_unique_2, Insts, InstMap, InstTable,
			ModuleInfo, Expansions).

inst_list_is_mostly_unique(Insts, InstMap, InstTable, ModuleInfo) :-
	set__init(Expansions),
	inst_list_has_property(inst_is_mostly_unique_2, Insts, InstMap,
			InstTable, ModuleInfo, Expansions).

inst_list_is_not_partly_unique(Insts, InstMap, InstTable, ModuleInfo) :-
	set__init(Expansions),
	inst_list_has_property(inst_is_not_partly_unique_2, Insts, InstMap,
			InstTable, ModuleInfo, Expansions).

inst_list_is_not_fully_unique(Insts, InstMap, InstTable, ModuleInfo) :-
	set__init(Expansions),
	inst_list_has_property(inst_is_not_fully_unique_2, Insts, InstMap,
			InstTable, ModuleInfo, Expansions).

%-----------------------------------------------------------------------------%

bound_inst_list_is_free([], _, _, _).
bound_inst_list_is_free([functor(_Name, Args)|BoundInsts], InstMap, InstTable,
		ModuleInfo) :-
	inst_list_is_free(Args, InstMap, InstTable, ModuleInfo),
	bound_inst_list_is_free(BoundInsts, InstMap, InstTable, ModuleInfo).

inst_list_is_free([], _, _, _).
inst_list_is_free([Inst | Insts], InstMap, InstTable, ModuleInfo) :-
	inst_is_free(Inst, InstMap, InstTable, ModuleInfo),
	inst_list_is_free(Insts, InstMap, InstTable, ModuleInfo).

%-----------------------------------------------------------------------------%

inst_list_is_ground_or_dead([], [], _InstMap, _InstTable, _ModuleInfo).
inst_list_is_ground_or_dead([Inst | Insts], [Live | Lives], InstMap, InstTable,
		ModuleInfo) :-
	( Live = live ->
		inst_is_ground(Inst, InstMap, InstTable, ModuleInfo)
	;
		true
	),
	inst_list_is_ground_or_dead(Insts, Lives, InstMap, InstTable,
		ModuleInfo).

inst_list_is_ground_or_any_or_dead([], [], _, _, _).
inst_list_is_ground_or_any_or_dead([Inst | Insts], [Live | Lives],
		InstMap, InstTable, ModuleInfo) :-
	( Live = live ->
		inst_is_ground_or_any(Inst, InstMap, InstTable, ModuleInfo)
	;
		true
	),
	inst_list_is_ground_or_any_or_dead(Insts, Lives, InstMap, InstTable,
		ModuleInfo).

%-----------------------------------------------------------------------------%

inst_contains_instname(Inst, InstMap, InstTable, ModuleInfo, InstName) :-
	set__init(Expansions),
	inst_contains_instname_2(Inst, InstMap, InstTable, ModuleInfo,
			Expansions, InstName).

:- pred inst_contains_instname_2(inst, instmap, inst_table, module_info,
		set(inst_name), inst_name).
:- mode inst_contains_instname_2(in, in, in, in, in, in) is semidet.

inst_contains_instname_2(defined_inst(InstName1), InstMap, InstTable,
		ModuleInfo, Expansions0, InstName) :-
	( InstName = InstName1 ->
		true
	;
		not set__member(InstName1, Expansions0),
		inst_lookup(InstTable, ModuleInfo, InstName1, Inst1),
		set__insert(Expansions0, InstName1, Expansions),
		inst_contains_instname_2(Inst1, InstMap, InstTable, ModuleInfo,
			Expansions, InstName)
	).
inst_contains_instname_2(bound(_Uniq, ArgInsts), InstMap, InstTable, ModuleInfo,
		Expansions, InstName) :-
	bound_inst_list_contains_instname(ArgInsts, InstMap, InstTable,
		ModuleInfo, Expansions, InstName).
inst_contains_instname_2(alias(InstKey), InstMap, InstTable, ModuleInfo,
		Expansions, InstName) :-
	inst_table_get_inst_key_table(InstTable, IKT),
	instmap__inst_key_table_lookup(InstMap, IKT, InstKey, Inst),
	inst_contains_instname_2(Inst, InstMap, InstTable, ModuleInfo,
		Expansions, InstName).

:- pred bound_inst_list_contains_instname(list(bound_inst), instmap,
		inst_table, module_info, set(inst_name), inst_name).
:- mode bound_inst_list_contains_instname(in, in, in, in, in, in) is semidet.

bound_inst_list_contains_instname([BoundInst|BoundInsts], InstMap, InstTable,
		ModuleInfo, Expansions, InstName) :-
	BoundInst = functor(_Functor, ArgInsts),
	(
		inst_list_contains_instname(ArgInsts, InstMap, InstTable,
			ModuleInfo, Expansions, InstName)
	;
		bound_inst_list_contains_instname(BoundInsts, InstMap,
			InstTable, ModuleInfo, Expansions, InstName)
	).

:- pred inst_list_contains_instname(list(inst), instmap, inst_table,
			module_info, set(inst_name), inst_name).
:- mode inst_list_contains_instname(in, in, in, in, in, in) is semidet.

inst_list_contains_instname([Inst|Insts], InstMap, InstTable, ModuleInfo,
		Expansions, InstName) :-
	(
		inst_contains_instname_2(Inst, InstMap, InstTable, ModuleInfo,
				Expansions, InstName)
	;
		inst_list_contains_instname(Insts, InstMap, InstTable,
				ModuleInfo, Expansions, InstName)
	).

%-----------------------------------------------------------------------------%

inst_contains_inst_key(InstMap, InstTable, ModuleInfo, Inst, Key) :-
	set__init(Expansions),
	inst_contains_inst_key_2(InstMap, InstTable, ModuleInfo, Expansions,
		Inst, Key).

:- pred inst_contains_inst_key_2(instmap, inst_table, module_info,
		set(inst_name), inst, inst_key).
:- mode inst_contains_inst_key_2(in, in, in, in, in, in) is semidet.

inst_contains_inst_key_2(InstMap, InstTable, ModuleInfo, Expansions,
		alias(Key0), Key) :-
	( instmap__inst_keys_are_equivalent(Key0, InstMap, Key, InstMap) ->
		true
	;
		inst_table_get_inst_key_table(InstTable, IKT),
		instmap__inst_key_table_lookup(InstMap, IKT, Key0, Inst),
		inst_contains_inst_key_2(InstMap, InstTable, ModuleInfo,
			Expansions, Inst, Key)
	).
inst_contains_inst_key_2(InstMap, InstTable, ModuleInfo, Expansions,
		bound(_, BoundInsts), Key) :-
	list__member(functor(_, Insts), BoundInsts),
	list__member(Inst, Insts),
	inst_contains_inst_key_2(InstMap, InstTable, ModuleInfo, Expansions,
		Inst, Key).
inst_contains_inst_key_2(InstMap, InstTable, ModuleInfo, Expansions0,
		defined_inst(InstName), Key) :-
	( set__member(InstName, Expansions0) ->
		fail
	;
		set__insert(Expansions0, InstName, Expansions),
		inst_lookup(InstTable, ModuleInfo, InstName, Inst),
		inst_contains_inst_key_2(InstMap, InstTable, ModuleInfo,
			Expansions, Inst, Key)
	).
inst_contains_inst_key_2(InstMap, InstTable, ModuleInfo, Expansions,
		abstract_inst(_, Insts), Key) :-
	list__member(Inst, Insts),
	inst_contains_inst_key_2(InstMap, InstTable, ModuleInfo, Expansions,
		Inst, Key).

%-----------------------------------------------------------------------------%

inst_contains_aliases(Inst, InstTable, ModuleInfo) :-
	set__init(Expansions),
	inst_contains_aliases_2(Inst, InstTable, ModuleInfo, Expansions).

:- pred inst_contains_aliases_2(inst, inst_table, module_info, set(inst_name)).
:- mode inst_contains_aliases_2(in, in, in, in) is semidet.

inst_contains_aliases_2(alias(_), _, _, _).
inst_contains_aliases_2(bound(_, BIs), InstTable, ModuleInfo, Expansions) :-
	list__member(functor(_, Insts), BIs),
	list__member(Inst, Insts),
	inst_contains_aliases_2(Inst, InstTable, ModuleInfo, Expansions).
inst_contains_aliases_2(abstract_inst(_, Insts), InstTable, ModuleInfo, 
		Expansions) :-
	list__member(Inst, Insts),
	inst_contains_aliases_2(Inst, InstTable, ModuleInfo, Expansions).
inst_contains_aliases_2(defined_inst(InstName), InstTable, ModuleInfo,
		Expansions0) :-
	\+ set__member(InstName, Expansions0),
	set__insert(Expansions0, InstName, Expansions),
	inst_lookup(InstTable, ModuleInfo, InstName, Inst),
	inst_contains_aliases_2(Inst, InstTable, ModuleInfo, Expansions).

%-----------------------------------------------------------------------------%

:- pred inst_contains_inst_var(inst, instmap, inst_table, module_info,
		inst_var).
:- mode inst_contains_inst_var(in, in, in, in, out) is nondet.

inst_contains_inst_var(Inst, InstMap, InstTable, ModuleInfo, InstVar) :-
	set__init(Expansions),
	inst_contains_inst_var_2(Inst, InstMap, InstTable, ModuleInfo,
			Expansions, InstVar).

:- pred inst_contains_inst_var_2(inst, instmap, inst_table, module_info,
		set(inst_name), inst_var).
:- mode inst_contains_inst_var_2(in, in, in, in, in, out) is nondet.

inst_contains_inst_var_2(inst_var(InstVar), _, _, _, _, InstVar).
inst_contains_inst_var_2(alias(Key), InstMap, InstTable, ModuleInfo, Expansions,
		InstVar) :-
	inst_table_get_inst_key_table(InstTable, IKT),
	instmap__inst_key_table_lookup(InstMap, IKT, Key, Inst),
	inst_contains_inst_var_2(Inst, InstMap, InstTable, ModuleInfo,
		Expansions, InstVar).
inst_contains_inst_var_2(defined_inst(InstName), InstMap, InstTable, ModuleInfo,
		Expansions0, InstVar) :-
	\+ set__member(InstName, Expansions0),
	inst_lookup(InstTable, ModuleInfo, InstName, Inst),
	set__insert(Expansions0, InstName, Expansions),
	inst_contains_inst_var_2(Inst, InstMap, InstTable, ModuleInfo,
		Expansions, InstVar).
inst_contains_inst_var_2(bound(_Uniq, ArgInsts), InstMap, InstTable,
		ModuleInfo, Expansions, InstVar) :-
	bound_inst_list_contains_inst_var(ArgInsts, InstMap, InstTable,
		ModuleInfo, Expansions, InstVar).
inst_contains_inst_var_2(ground(_Uniq, PredInstInfo), InstMap, _InstTable,
		ModuleInfo, Expansions, InstVar) :-
	PredInstInfo = yes(pred_inst_info(_PredOrFunc,
		argument_modes(ArgInstTable, Modes), _Det)),
	mode_list_contains_inst_var_2(Modes, InstMap, ArgInstTable, ModuleInfo,
		Expansions, InstVar).
inst_contains_inst_var_2(abstract_inst(_Name, ArgInsts), InstMap, InstTable,
		ModuleInfo, Expansions, InstVar) :-
	inst_list_contains_inst_var(ArgInsts, InstMap,
		InstTable, ModuleInfo, Expansions, InstVar).

:- pred bound_inst_list_contains_inst_var(list(bound_inst), instmap,
			inst_table, module_info, set(inst_name), inst_var).
:- mode bound_inst_list_contains_inst_var(in, in, in, in, in, out) is nondet.

bound_inst_list_contains_inst_var([BoundInst|BoundInsts], InstMap, InstTable,
		ModuleInfo, Expansions, InstVar) :-
	BoundInst = functor(_Functor, ArgInsts),
	(
		inst_list_contains_inst_var(ArgInsts, InstMap, InstTable,
			ModuleInfo, Expansions, InstVar)
	;
		bound_inst_list_contains_inst_var(BoundInsts, InstMap,
			InstTable, ModuleInfo, Expansions, InstVar)
	).

:- pred inst_list_contains_inst_var(list(inst), instmap, inst_table,
		module_info, set(inst_name), inst_var).
:- mode inst_list_contains_inst_var(in, in, in, in, in, out) is nondet.

inst_list_contains_inst_var([Inst|Insts], InstMap, InstTable, ModuleInfo,
		Expansions, InstVar) :-
	(
		inst_contains_inst_var_2(Inst, InstMap, InstTable, ModuleInfo,
			Expansions, InstVar)
	;
		inst_list_contains_inst_var(Insts, InstMap, InstTable,
			ModuleInfo, Expansions, InstVar)
	).

mode_list_contains_inst_var(Modes, InstMap, InstTable, ModuleInfo, InstVar) :-
	set__init(Expansions),
	mode_list_contains_inst_var_2(Modes, InstMap, InstTable, ModuleInfo,
		Expansions, InstVar).

:- pred mode_list_contains_inst_var_2(list(mode), instmap, inst_table,
		module_info, set(inst_name), inst_var).
:- mode mode_list_contains_inst_var_2(in, in, in, in, in, out) is nondet.

mode_list_contains_inst_var_2([Mode|_Modes], InstMap, InstTable, ModuleInfo,
		Expansions, InstVar) :-
	mode_get_insts_semidet(ModuleInfo, Mode, Initial, Final),
	( Inst = Initial ; Inst = Final ),
	inst_contains_inst_var_2(Inst, InstMap, InstTable, ModuleInfo,
		Expansions, InstVar).
mode_list_contains_inst_var_2([_|Modes], InstMap, InstTable, ModuleInfo,
		Expansions, InstVar) :-
	mode_list_contains_inst_var_2(Modes, InstMap, InstTable, ModuleInfo,
		Expansions, InstVar).

%-----------------------------------------------------------------------------%

inst_has_representation(Inst, InstMap, InstTable, Type, ModuleInfo) :-
	(
		% is this a no_tag type?
		type_constructors(Type, ModuleInfo, Constructors),
		type_is_no_tag_type(Constructors, FunctorName, ArgType)
	->
		% the arg_mode will be determined by the mode and
		% type of the functor's argument,
		% so we figure out the mode and type of the argument,
		% and then recurse
		ConsId = cons(FunctorName, 1),
		get_single_arg_inst(Inst, InstMap, InstTable, ModuleInfo,
			ConsId, ArgInst),
		inst_has_representation(ArgInst, InstMap, InstTable,
			ArgType, ModuleInfo)
	;
		inst_has_representation_2(Inst, InstMap, InstTable, ModuleInfo)
	).


:- pred inst_has_representation_2(inst, instmap, inst_table, module_info).
:- mode inst_has_representation_2(in, in, in, in) is semidet.

inst_has_representation_2(any(_), _, _, _).
inst_has_representation_2(alias(Key), InstMap, InstTable, ModuleInfo) :-
	inst_table_get_inst_key_table(InstTable, IKT),
	instmap__inst_key_table_lookup(InstMap, IKT, Key, Inst),
	inst_has_representation_2(Inst, InstMap, InstTable, ModuleInfo).
inst_has_representation_2(free(alias), _, _, _).
inst_has_representation_2(free(alias, _), _, _, _).
inst_has_representation_2(bound(_, _), _, _, _).
inst_has_representation_2(ground(_, _), _, _, _).
inst_has_representation_2(not_reached, _, _, _) :-
	error("inst_has_representation_2: not_reached").
inst_has_representation_2(inst_var(_), _, _, _) :-
	error("inst_has_representation_2: uninstantiated inst parameter").
inst_has_representation_2(defined_inst(InstName), InstMap, InstTable,
		ModuleInfo) :-
	inst_lookup(InstTable, ModuleInfo, InstName, Inst2),
	inst_has_representation_2(Inst2, InstMap, InstTable, ModuleInfo).
inst_has_representation_2(abstract_inst(_, _), _, _, _).

%-----------------------------------------------------------------------------%
%-----------------------------------------------------------------------------%
