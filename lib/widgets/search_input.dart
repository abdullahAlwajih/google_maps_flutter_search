import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter_search/entities/localization_item.dart';

/// Custom Search input field, showing the search and clear icons.
class SearchInput extends StatefulWidget {
  final ValueChanged<String> onSearchInput;
  final Messages messages;
  const SearchInput(this.onSearchInput, {required this.messages,Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => SearchInputState();
}

class SearchInputState extends State<SearchInput> {
  TextEditingController editController = TextEditingController();

  Timer? debouncer;

  bool hasSearchEntry = false;

  SearchInputState();

  @override
  void initState() {
    super.initState();
    editController.addListener(onSearchInputChange);
  }

  @override
  void dispose() {
    editController.removeListener(onSearchInputChange);
    editController.dispose();

    super.dispose();
  }

  void onSearchInputChange() {
    if (editController.text.isEmpty) {
      debouncer?.cancel();
      widget.onSearchInput(editController.text);
      return;
    }

    if (debouncer?.isActive ?? false) {
      debouncer!.cancel();
    }

    debouncer = Timer(const Duration(milliseconds: 500), () {
      widget.onSearchInput(editController.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    // SafeArea(
    //   child: PreferredSize(
    //     preferredSize: Size.zero,
    //     child: StatefulBuilder(builder: (context, setState) {
    //       return Padding(
    //           padding: const EdgeInsetsDirectional.fromSTEB(
    //               4 , 4, 4, 4),
    //           child:
    //           Theme(
    //             data_provider: Theme.of(context)
    //                 .copyWith(primaryColor: Theme.of(context).colorScheme.primary),
    //             child: Stack(
    //               children: [
    //                 TextFormField(
    //                   // controller: _con!.searchController,
    //
    //
    //                   onChanged: (String value) {
    //                     // _con!.applySearch(context, value);
    //                   },
    //                   onTap: () {
    //                     // scrollController.animateTo(268,
    //                     //     duration: const Duration(seconds: 1),
    //                     //     curve: Curves.decelerate);
    //                   },
    //                 )
    //               ],
    //             ),
    //           )
    //
    //       );
    //     }),
    //   ),
    // )

    return SafeArea(
      child: PreferredSize(
          preferredSize: Size.zero,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: const BorderRadius.all(Radius.circular(100)),
                          boxShadow: [
                            BoxShadow(
                              blurRadius: 50,
                              color: Theme.of(context).hintColor.withOpacity(0.1),
                            )
                          ]),
                    ),
                    TextFormField(
                      decoration: InputDecoration(
                          suffixIcon: Icon(
                            Icons.search,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          hintText: widget.messages.findYourLocation,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          hintStyle: Theme.of(context)
                              .textTheme
                              .caption!
                              .copyWith(fontSize: 14),
                          disabledBorder: OutlineInputBorder(
                              borderRadius:
                              BorderRadius.circular(100),
                              borderSide: const BorderSide(
                                  color: Colors.transparent))),
                      cursorColor: Theme.of(context).colorScheme.primary,
                      textInputAction: TextInputAction.done,
                      // decoration: const InputDecoration(hintText: "Search place", border: InputBorder.none),
                      controller: editController,
                      onChanged: (value) => setState(() => hasSearchEntry = value.isNotEmpty),
                    ),
                  ],
                ),
              ),
              // if (hasSearchEntry)
              //   GestureDetector(
              //     child: const Icon(Icons.clear),
              //     onTap: () {
              //       editController.clear();
              //       setState(() => hasSearchEntry = false);
              //     },
              //   ),
            ],
          ),
        ),
      ),
    );
  }
}
