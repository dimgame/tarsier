import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_section_list/flutter_section_list.dart';

import 'package:dim_flutter/dim_flutter.dart';
import 'package:lnc/lnc.dart' as lnc;

import 'chat_box.dart';


class StrangerListPage extends StatefulWidget {
  const StrangerListPage({super.key});

  static void open(BuildContext context) => showCupertinoDialog(
    context: context,
    builder: (context) => const StrangerListPage(),
  );

  @override
  State<StatefulWidget> createState() => _StrangerListState();
}

class _StrangerListState extends State<StrangerListPage> implements lnc.Observer {
  _StrangerListState() : _clerk = Amanuensis() {
    _adapter = _StrangerListAdapter(dataSource: _clerk);

    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kConversationUpdated);
    nc.addObserver(this, NotificationNames.kContactsUpdated);
    nc.addObserver(this, NotificationNames.kBlockListUpdated);
  }

  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kBlockListUpdated);
    nc.removeObserver(this, NotificationNames.kContactsUpdated);
    nc.removeObserver(this, NotificationNames.kConversationUpdated);
    super.dispose();
  }

  final Amanuensis _clerk;

  late final _StrangerListAdapter _adapter;

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? userInfo = notification.userInfo;
    if (name == NotificationNames.kConversationUpdated) {
      ID? chat = userInfo?['ID'];
      Log.warning('conversation updated: $chat');
      await _reload();
    } else if (name == NotificationNames.kContactsUpdated) {
      Log.warning('contacts updated');
      await _reload();
    } else if (name == NotificationNames.kBlockListUpdated) {
      Log.warning('block-list updated');
      await _reload();
    }
  }

  Future<void> _reload() async {
    await _clerk.loadConversations();
    if (mounted) {
      setState(() {
        _adapter.notifyDataChange();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Facade.of(context).colors.scaffoldBackgroundColor,
    appBar: CupertinoNavigationBar(
      backgroundColor: Facade.of(context).colors.appBardBackgroundColor,
      middle: StatedTitleView.from(context, () => 'New Friends'),
    ),
    body: SectionListView.builder(
      adapter: _adapter,
    ),
  );
}

class _StrangerListAdapter with SectionAdapterMixin {
  _StrangerListAdapter({required Amanuensis dataSource}) : _dataSource = dataSource;

  final Amanuensis _dataSource;

  @override
  int numberOfItems(int section) => _dataSource.strangers.length;

  @override
  Widget getItem(BuildContext context, IndexPath indexPath) {
    List<Conversation> conversations = _dataSource.strangers;
    if (indexPath.item >= conversations.length) {
      Log.error('out of range: ${conversations.length}, $indexPath');
      return const Text('null');
    }
    Conversation info = conversations[indexPath.item];
    Log.warning('show item: $info');
    return _ChatTableCell(info);
  }

}

/// TableCell for Conversations
class _ChatTableCell extends StatefulWidget {
  const _ChatTableCell(this.info);

  final Conversation info;

  @override
  State<StatefulWidget> createState() => _ChatTableCellState();

}

class _ChatTableCellState extends State<_ChatTableCell> implements lnc.Observer {
  _ChatTableCellState() {

    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kDocumentUpdated);
  }

  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kDocumentUpdated);
    super.dispose();
  }

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? userInfo = notification.userInfo;
    ID? cid = userInfo?['ID'];
    if (cid == null) {
      Log.error('notification error: $notification');
    }
    if (name == NotificationNames.kDocumentUpdated) {
      if (cid == widget.info.identifier) {
        await _reload();
      } else {
        // TODO: check members for group chat?
      }
    } else {
      assert(false, 'notification error: $notification');
    }
  }

  Future<void> _reload() async {
    await widget.info.reloadData();
    if (mounted) {
      setState(() {
        //
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  Widget build(BuildContext context) => CupertinoTableCell(
    leading: _leading(widget.info),
    title: Text(widget.info.name),
    subtitle: _lastMessage(widget.info.lastMessage),
    additionalInfo: _timeLabel(widget.info.lastTime),
    // trailing: const CupertinoListTileChevron(),
    onTap: () {
      Log.warning('tap: ${widget.info}');
      ChatBox.open(context, widget.info);
    },
    onLongPress: () {
      Log.warning('long press: ${widget.info}');
      Alert.actionSheet(context,
        'Confirm', 'Are you sure to remove this friend?',
        'Remove ${widget.info.name}',
            () => _removeConversation(context, widget.info.identifier),
      );
    },
  );

  void _removeConversation(BuildContext context, ID chat) {
    Log.warning('removing $chat');
    Amanuensis clerk = Amanuensis();
    clerk.removeConversation(chat).onError((error, stackTrace) {
      Alert.show(context, 'Error', 'Failed to remove friend');
      return false;
    });
  }

  Widget _leading(Conversation info) => BadgeView(info.getImage(), info.unread);

  Widget? _lastMessage(String? last) {
    if (last == null) {
      return null;
    }
    return Text(last);
  }

  Widget? _timeLabel(DateTime? time) {
    if (time == null) {
      return null;
    }
    return Text(TimeUtils.getTimeString(time));
  }
}
