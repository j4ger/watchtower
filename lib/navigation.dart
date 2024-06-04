import 'package:flutter/material.dart';

import 'bluetooth_page/bluetooth_page.dart';
import 'mock_page/mock_page.dart';
import 'record_page/record_page.dart';
import 'signal_page/signal_page.dart';
import 'view_record_page/view_record_page.dart';

/// start with bluetooth view
const entryURL = "/bluetooth";

/// all pages should be provided
final List<AppPage> navigationList = [
  AppPage("bluetooth", "Setup Bluetooth Device", () => BluetoothPage(),
      Icons.devices_other, Icons.devices_other_outlined),
  AppPage("mock", "Setup Mock Device", () => MockPage(), Icons.file_open,
      Icons.file_open_outlined),
  AppPage("signal", "View Signal", () => SignalPage(), Icons.timeline,
      Icons.timeline_outlined,
      hidden: true),
  AppPage("record", "Record Management", () => RecordPage(), Icons.save,
      Icons.save_rounded),
  AppPage("viewRecord", "View Signal Record", () => ViewRecordPage(),
      Icons.troubleshoot, Icons.troubleshoot_outlined,
      hidden: true)
];

/// hide pages marked with "hidden: true"
final List<AppPage> shownNavigationList =
    navigationList.where((item) => !item.hidden).toList();

class AppPage {
  /// internal name for navigation
  final String name;

  /// appbar title
  final String title;

  /// page content (created with makePage function)
  final Widget Function() page;

  /// icon for navigation drawer
  final IconData icon;

  /// icon when selected
  final IconData selectedIcon;

  /// should this page be hidden in navigationDrawer
  final bool hidden;

  AppPage(this.name, this.title, this.page, this.icon, this.selectedIcon,
      {this.hidden = false});
}

/// appbar implementation
class DefaultAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showDrawerButton;
  final List<Widget> actions;
  const DefaultAppBar(this.title,
      {this.showDrawerButton = true, this.actions = const [], super.key});

  @override
  Widget build(BuildContext context) {
    final ScaffoldState? scaffoldState =
        context.findRootAncestorStateOfType<ScaffoldState>();
    return AppBar(
      leading: showDrawerButton
          ? IconButton(
              icon: const Icon(Icons.menu),
              onPressed: scaffoldState?.openDrawer,
            )
          : null,
      title: Text(title),
      actions: actions,
    );
  }

  @override
  final Size preferredSize = const Size.fromHeight(kToolbarHeight);
}

/// function for making a page
/// injects appbar and routing information
Widget makePage(String title, Widget body,
        {bool showDrawerButton = true,
        List<Widget> actions = const [],
        Widget? floatingActionButton}) =>
    Scaffold(
      appBar: DefaultAppBar(title,
          showDrawerButton: showDrawerButton, actions: actions),
      body: SafeArea(child: body),
      floatingActionButton: floatingActionButton,
    );
