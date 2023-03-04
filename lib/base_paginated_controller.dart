import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:riverpod/riverpod.dart';

import 'paginated_state.dart';


typedef SearchProvider<T,F> = Future<List<T>> Function(
    BasePaginatedController<T,F> controller);

class BasePaginatedController<T, F> extends StateNotifier<PaginatedState<T>> {
  final List<T> _items = [];
  final SearchProvider<T,F> searchProvider;
  final int batchSize;
  final TextEditingController searchController = TextEditingController();
  final debounceDuration = const Duration(milliseconds: 500);
  // helper getter
  String get query => searchController.text;
  // mutable variables
  F currentFilter;
  bool hasNoMoreItems = false;
  int page = 1;

  // to debounce multiple requests
  Timer _timer = Timer(const Duration(milliseconds: 0), () {});

  BasePaginatedController({
    required this.searchProvider,
    required this.batchSize,
    required this.currentFilter,
  }) : super(const PaginatedState.data([]));

  // appends the data to the previous [_items]
  void updateItems(List<T> results) {
    hasNoMoreItems = results.length < batchSize;

    if (results.isEmpty) {
      state = PaginatedState.data(_items);
    } else {
      state = PaginatedState.data(_items..addAll(results));
    }
  }

  /// searches for the content inside the [searchController]
  /// resets all the other class variables such as [_items], [hasNoMoreItems], and [page]
  void search() async {
    if (query.isEmpty) {
      // if the search is empty, just show them the current items, no need to search
      state = PaginatedState.data(_items);
      return;
    }

    state = const PaginatedState.loading();

    String savedQuery = query;
    // debounce search if this function is called within the given timeframe
    await Future.delayed(debounceDuration);

    if (savedQuery != query) {
      // there was another search issued, we will complete the other search and skip this one
      debugPrint('debounced search $savedQuery');
      return;
    }

    // resetting the variables for this new search
    _items.clear();
    hasNoMoreItems = false;
    page = 1;

    _performSearch();
  }

  /// set the filter and do a [search]
  void setFilter(F filter, {bool performSearch = true}) {
    currentFilter = filter;
    if (performSearch) {
      search();
    }
  }

  /// Fetch the next set of items from the same search
  Future<void> fetchNextBatch() async {

    if (_timer.isActive) {
      // already processing another request
      return;
    }

    _startTimer();

    if (hasNoMoreItems) {
      return;
    } else if (state == PaginatedState.onGoingLoading(_items)) {
      return;
    }

    debugPrint('fetchNextBatch $query');
    // use the same query to fetch the next items in search
    // show ongoing loading
    state = PaginatedState.onGoingLoading(_items);
    // increase the page number
    page += 1;

    _performSearch();
  }

  // starts the timer so that we don't perform multiple searches at once while
  // another search is in process (timer is active)
  void _startTimer() {
    _timer = Timer(const Duration(seconds: 1), () { });
  }

  /// calls the passed in [searchProvider] to retrieve items
  Future<void> _performSearch() async {
    List<T> results = await searchProvider(this);
    updateItems(results);
  }
}
