import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pure_live/core/sites.dart';
import 'package:pure_live/common/l10n/generated/l10n.dart';
import 'package:pure_live/modules/search/search_controller.dart' as customer_com;

import 'search_list_view.dart';

class SearchPage extends GetView<customer_com.SearchController> {
  const SearchPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: TextField(
          controller: controller.searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: S.of(context).search_input_hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12.0),
            prefixIcon: IconButton(
              onPressed: Get.back,
              icon: const Icon(Icons.arrow_back),
            ),
            suffixIcon: IconButton(
              onPressed: controller.doSearch,
              icon: const Icon(Icons.search),
            ),
          ),
          onSubmitted: (e) {
            controller.doSearch();
          },
        ),
        bottom: TabBar(
          controller: controller.tabController,
          padding: EdgeInsets.zero,
          tabs: Sites.supportSites.map((e) => Tab(text: e.name)).toList(),
          isScrollable: false,
          indicatorSize: TabBarIndicatorSize.label,
        ),
      ),
      body: TabBarView(
        controller: controller.tabController,
        children: Sites.supportSites.map((e) => SearchListView(e.id)).toList(),
      ),
    );
  }
}
