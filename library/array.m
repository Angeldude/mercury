%-----------------------------------------------------------------------------%

% array.nl

% Main author: conway.

% this file contains a set of predicates for generating an manipulating
% an array data structure. The implementation uses 2-3 trees to yield
% O(logN) performance for accesses and updates. Array creation is an
% O(NlogN) process.

% arrays are created with any two integer bounds on the indices.

%-----------------------------------------------------------------------------%

:- module array.
:- import_module integer.

:- type subarray(T)	--->	node(T)
			;	two(
					integer,
					integer,
					array(T),
					array(T)
				)
			;	three(
					integer,
					integer,
					array(T),
					array(T),
					array(T)
				).

% array__init creates an array with bounds from Low to High, with each
% element initialized to Init.
:- pred array__init(integer, integer, T, array(T)).
:- mode array__init(input, input, input, output). % want an array_skeleton?

% array__bounds returns the upper and lower bounds of an array.
:- pred array__bounds(array(T), integer, integer).
:- mode array__bounds(input, output, output).

% array__search returns the Nth element of an array - or fails if the index
% is out of bounds.
:- pred array__search(array(T), integer, T).
:- mode array__search(input, input, output).

% array__set sets the nth element of an array, and returns the resulting 
% array (good oppertunity for destructive update ;-). It fails if the
% index is out of bounds.
:- pred array__set(array(T), integer, T, array(T)).
:- mode array__set(input, input, input, output).

% array__from_list takes a list (of nonzero length), and returns an array
% containing those elements in the same order that they occured in the list.
:- pred array__from_list(list(T), array(T)).
:- mode array__from_list(input, output).

% array__to_list takes an array and returns a list containing the elements
% of the array in the same order that they occured in the array.
:- pred array__to_list(array(T), list(T)).
:- mode array__to_list(input, output).

%-----------------------------------------------------------------------------%

:- implementation.

array__init(Low, High, Init, Array) :-
	Size0 is High - Low,
	Size is Size0 + 1,
	(if
		Size = 0
	then
		require(fail, "Cannot have a zero length array")
	else if
		Size = 1
	then
		Array = node(Init)
	else if
		Size = 2
	then
		Array = two(Low, High, node(Init), node(Init))
	else if
		Size = 3
	then
		Array = three(Low, High, node(Init), node(Init), node(Init))
	else if
		some [M] (
			0 is Size mod 2,
			M is Size mod 3,
			not(M = 3)
		)
	then
		N is Size // 2,
		L2 is Low + N,
		H1 is L2 - 1,
		array__init(Low, H1, Init, A1),
		array__init(L2, High, Init, A2),
		Array = two(Low, High, A1, A2)
	else 
		N is Size // 3,
		L2 is Low + N,
		L3 is L2 + N,
		H1 is L2 - 1,
		H2 is L3 - 1,
		array__init(Low, H1, Init, A1),
		array__init(L2, H2, Init, A2),
		array__init(L3, High, Init, A3),
		Array = three(Low, High, A1, A2, A3)
	).

array__bounds(node(_), 0, 0).
array__bounds(two(Low, High, _, _), Low, High).
array__bounds(three(Low, High, _, _, _), Low, High).

array__search(node(Item), Index, Item).
array__search(two(Low, High, Left, Right), Index, Item) :-
	Size is High - Low,
	Half is Size / 2,
	Mid is Low + Half,
	(if
		Index < Mid
	then
		array__search(Left, Index, Item)
	else
		array__search(Right, Index, Item)
	).
array__search(three(Low, High, Left, Middle, Right), Index, Item) :-
	Size is High - Low,
	Third is Size / 3,
	Mid1 is Low + Third,
	Mid2 is Mid1 + Third,
	(if
		Index < Mid1
	then
		array__search(Left, Index, Item)
	else if
		Index < Mid2
	then
		array__search(Middle, Index, Item)
	else
		array__search(Right, Index, Item)
	).

array__set(node(_), Index, Item, node(Item)).
array__set(two(Low, High, Left, Right), Index, Item, A) :-
	Size is High - Low,
	Half is Size / 2,
	Mid is Low + Half,
	(if
		Index < Mid
	then
		array__set(Left, Index, Item, Left1),
		A = two(Low, High, Left1, Right)
	else
		array__set(Right, Index, Item, Right1),
		A = two(Low, High, Left, Right1)
	).
array__set(three(Low, High, Left, Middle, Right), Index, Item, A) :-
	Size is High - Low,
	Third is Size / 3,
	Mid1 is Low + Third,
	Mid2 is Mid1 + Third,
	(if
		Index < Mid1
	then
		array__set(Left, Index, Item, Left1),
		A = three(Low, High, Left1, Middle, Right)
	else if
		Index < Mid2
	then
		array__set(Middle, Index, Item, Middle1),
		A = three(Low, High, Left, Middle1, Right)
	else
		array__set(Right, Index, Item, Right1),
		A = three(Low, High, Left, Middle, Right1)
	).

array__from_list([], _Array) :-
	require(fail, "Cannot create an array with zero elements").

array__from_list(List, Array) :-
	length(List, Len),
	Len1 is Len - 1,
	List = [Head | Tail],
	array__init(0, Len1, Head, Array0),
	array__insert_items(Array0, 1, Tail, Array).

array__insert_items(Array, N, [], Array).
array__insert_items(Array0, N, [Head|Tail], Array) :-
	array__set(Array0, N, Head, Array1),
	N1 is N + 1,
	array__insert_items(Array1, N1, Tail, Array).

array__to_list(Array, List) :-
	array__bounds(Array, Low, High),
	array__fetch_items(Array, Low, High, List).

array__fetch_items(Array, Low, High, List) :-
	(if
		Low > High
	then 
		List = []
	else
		Low1 is Low + 1,
		array__fetch_items(Array, Low1, High, List0),
		array__search(Array, Low, Item),
		List = [Item|List0]
	).

%-----------------------------------------------------------------------------%
