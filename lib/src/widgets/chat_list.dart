import 'package:diffutil_dart/diffutil.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;

import '../models/bubble_rtl_alignment.dart';
import 'state/inherited_chat_theme.dart';
import 'state/inherited_user.dart';
import 'typing_indicator.dart';

/// Animated list that handles automatic animations and pagination.
class ChatList extends StatefulWidget {
  /// Creates a chat list widget.
  const ChatList({
    super.key,
    this.bottomWidget,
    required this.bubbleRtlAlignment,
    this.isLastPage,
    required this.itemBuilder,
    required this.items,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.onEndReached,
    this.onEndReachedThreshold,
    required this.scrollController,
    this.scrollPhysics,
    this.typingIndicatorOptions,
    required this.useTopSafeAreaInset,
    this.customStructureBuilder,
  });

  /// A custom widget at the bottom of the list.
  final Widget? bottomWidget;

  /// Used to set alignment of typing indicator.
  /// See [BubbleRtlAlignment].
  final BubbleRtlAlignment bubbleRtlAlignment;

  /// Used for pagination (infinite scroll) together with [onEndReached].
  /// When true, indicates that there are no more pages to load and
  /// pagination will not be triggered.
  final bool? isLastPage;

  /// Item builder.
  final Widget Function(Object, int? index) itemBuilder;

  /// Items to build.
  final List<Object> items;

  /// Used for pagination (infinite scroll). Called when user scrolls
  /// to the very end of the list (minus [onEndReachedThreshold]).
  final Future<void> Function()? onEndReached;

  /// A representation of how a [ScrollView] should dismiss the on-screen keyboard.
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;

  /// Used for pagination (infinite scroll) together with [onEndReached]. Can be anything from 0 to 1, where 0 is immediate load of the next page as soon as scroll starts, and 1 is load of the next page only if scrolled to the very end of the list. Default value is 0.75, e.g. start loading next page when scrolled through about 3/4 of the available content.
  final double? onEndReachedThreshold;

  /// Scroll controller for the main [CustomScrollView]. Also used to auto scroll
  /// to specific messages.
  final ScrollController scrollController;

  /// Determines the physics of the scroll view.
  final ScrollPhysics? scrollPhysics;

  /// Used to build typing indicator according to options.
  /// See [TypingIndicatorOptions].
  final TypingIndicatorOptions? typingIndicatorOptions;

  /// Whether to use top safe area inset for the list.
  final bool useTopSafeAreaInset;

  /// Defines a customizable structure builder for a chat list widget.
  ///
  /// This function type is used to create a custom structure for the chat list,
  /// allowing for extensive customization of its appearance and behavior. It
  /// takes several parameters that control various aspects of the chat list,
  /// including scrolling behavior, typing indicators, and message display.
  ///
  /// Parameters:
  /// - `scrollController`: Controls the scroll behavior of the chat list.
  /// - `keyboardDismissBehavior`: Determines how the keyboard dismissal is handled.
  /// - `scrollPhysics`: Defines the physics of the scrolling content.
  /// - `reverse`: Whether the list should be displayed in reverse order.
  /// - `bottomWidget`: A widget to display at the bottom of the list.
  /// - `typingIndicatorOptions`: Configuration for the typing indicator.
  /// - `bubbleRtlAlignment`: Alignment of message bubbles.
  /// - `indicatorOnScrollStatus`: Status of the scroll indicator.
  /// - `isNextPageLoading`: Indicates if the next page is currently loading.
  /// - `animation`: Controls animations within the chat list.
  /// - `items`: The list of items to display in the chat.
  /// - `itemBuilder`: A builder function for creating item widgets.
  /// - `onEndReachedThreshold`: Threshold for triggering the loading of the next page.
  /// - `onEndReached`: Callback function called when the end of the list is reached.
  /// - `useTopSafeAreaInset`: Whether to adjust for the top safe area inset.
  /// - `listKey`: Key for the list widget.
  ///
  /// Returns a widget that represents the customized structure of the chat list.
  final Widget Function(
    ScrollController scrollController,
    ScrollViewKeyboardDismissBehavior keyboardDismissBehavior,
    ScrollPhysics? scrollPhysics,
    bool reverse,
    Widget? bottomWidget,
    TypingIndicatorOptions? typingIndicatorOptions,
    BubbleRtlAlignment bubbleRtlAlignment,
    bool indicatorOnScrollStatus,
    bool isNextPageLoading,
    Animation<double> animation,
    List<Object> items,
    Widget Function(int index, Animation<double> animation) itemBuilder,
    double? onEndReachedThreshold,
    Future<void> Function()? onEndReached,
    bool useTopSafeAreaInset,
    Key? listKey,
   // nt? Function(Key)?  findChildIndexCallback,
  )? customStructureBuilder;

  @override
  State<ChatList> createState() => _ChatListState();
}

/// [ChatList] widget state.
class _ChatListState extends State<ChatList>
    with SingleTickerProviderStateMixin {
  late final Animation<double> _animation = CurvedAnimation(
    curve: Curves.easeOutQuad,
    parent: _controller,
  );
  late final AnimationController _controller = AnimationController(vsync: this);

  bool _indicatorOnScrollStatus = false;
  bool _isNextPageLoading = false;
  final GlobalKey<SliverAnimatedListState> _listKey =
      GlobalKey<SliverAnimatedListState>();
  late List<Object> _oldData = List.from(widget.items);

  @override
  void initState() {
    super.initState();

    didUpdateWidget(widget);
  }

  void _calculateDiffs(List<Object> oldList) async {
    final diffResult = calculateListDiff<Object>(
      oldList,
      widget.items,
      equalityChecker: (item1, item2) {
        if (item1 is Map<String, Object> && item2 is Map<String, Object>) {
          final message1 = item1['message']! as types.Message;
          final message2 = item2['message']! as types.Message;

          return message1.id == message2.id;
        } else {
          return item1 == item2;
        }
      },
    );

    for (final update in diffResult.getUpdates(batch: false)) {
      update.when(
        insert: (pos, count) {
          _listKey.currentState?.insertItem(pos);
        },
        remove: (pos, count) {
          final item = oldList[pos];
          _listKey.currentState?.removeItem(
            pos,
            (_, animation) => _removedMessageBuilder(item, animation),
          );
        },
        change: (pos, payload) {},
        move: (from, to) {},
      );
    }

    _scrollToBottomIfNeeded(oldList);

    _oldData = List.from(widget.items);
  }

  Widget _newMessageBuilder(int index, Animation<double> animation) {
    try {
      final item = _oldData[index];

      return SizeTransition(
        key: _valueKeyForItem(item),
        axisAlignment: -1,
        sizeFactor: animation.drive(CurveTween(curve: Curves.easeOutQuad)),
        child: widget.itemBuilder(item, index),
      );
    } catch (e) {
      return const SizedBox();
    }
  }

  Widget _removedMessageBuilder(Object item, Animation<double> animation) =>
      SizeTransition(
        key: _valueKeyForItem(item),
        axisAlignment: -1,
        sizeFactor: animation.drive(CurveTween(curve: Curves.easeInQuad)),
        child: FadeTransition(
          opacity: animation.drive(CurveTween(curve: Curves.easeInQuad)),
          child: widget.itemBuilder(item, null),
        ),
      );

  // Hacky solution to reconsider.
  void _scrollToBottomIfNeeded(List<Object> oldList) {
    try {
      // Take index 1 because there is always a spacer on index 0.
      final oldItem = oldList[1];
      final item = widget.items[1];

      if (oldItem is Map<String, Object> && item is Map<String, Object>) {
        final oldMessage = oldItem['message']! as types.Message;
        final message = item['message']! as types.Message;

        // Compare items to fire only on newly added messages.
        if (oldMessage.id != message.id) {
          // Run only for sent message.
          if (message.author.id == InheritedUser.of(context).user.id) {
            // Delay to give some time for Flutter to calculate new
            // size after new message was added.
            Future.delayed(const Duration(milliseconds: 100), () {
              if (widget.scrollController.hasClients) {
                widget.scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInQuad,
                );
              }
            });
          }
        }
      }
    } catch (e) {
      // Do nothing if there are no items.
    }
  }

  Key? _valueKeyForItem(Object item) =>
      _mapMessage(item, (message) => ValueKey(message.id));

  T? _mapMessage<T>(Object maybeMessage, T Function(types.Message) f) {
    if (maybeMessage is Map<String, Object>) {
      return f(maybeMessage['message'] as types.Message);
    }
    return null;
  }

  @override
  void didUpdateWidget(covariant ChatList oldWidget) {
    super.didUpdateWidget(oldWidget);

    _calculateDiffs(oldWidget.items);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.pixels > 10.0 && !_indicatorOnScrollStatus) {
            setState(() {
              _indicatorOnScrollStatus = !_indicatorOnScrollStatus;
            });
          } else if (notification.metrics.pixels == 0.0 &&
              _indicatorOnScrollStatus) {
            setState(() {
              _indicatorOnScrollStatus = !_indicatorOnScrollStatus;
            });
          }

          if (widget.onEndReached == null || widget.isLastPage == true) {
            return false;
          }

          if (notification.metrics.pixels >=
              (notification.metrics.maxScrollExtent *
                  (widget.onEndReachedThreshold ?? 0.75))) {
            if (widget.items.isEmpty || _isNextPageLoading) return false;

            _controller.duration = Duration.zero;
            _controller.forward();

            setState(() {
              _isNextPageLoading = true;
            });

            widget.onEndReached!().whenComplete(() {
              if (mounted) {
                _controller.duration = const Duration(milliseconds: 300);
                _controller.reverse();

                setState(() {
                  _isNextPageLoading = false;
                });
              }
            });
          }

          return false;
        },
        child: widget.customStructureBuilder?.call(
              widget.scrollController,
              widget.keyboardDismissBehavior,
              widget.scrollPhysics,
              false,
              widget.bottomWidget,
              widget.typingIndicatorOptions,
              widget.bubbleRtlAlignment,
              _indicatorOnScrollStatus,
              _isNextPageLoading,
              _animation,
              widget.items,
              // widget.itemBuilder,
              _newMessageBuilder,
              widget.onEndReachedThreshold,
              widget.onEndReached,
              widget.useTopSafeAreaInset,
              _listKey,
            ) ??
            CustomScrollView(
              controller: widget.scrollController,
              keyboardDismissBehavior: widget.keyboardDismissBehavior,
              physics: widget.scrollPhysics,
              reverse: true,
              slivers: [
                if (widget.bottomWidget != null)
                  SliverToBoxAdapter(child: widget.bottomWidget),
                SliverPadding(
                  padding: const EdgeInsets.only(bottom: 4),
                  sliver: SliverToBoxAdapter(
                    child: (widget.typingIndicatorOptions!.typingUsers
                                .isNotEmpty &&
                            !_indicatorOnScrollStatus)
                        ? (widget.typingIndicatorOptions
                                    ?.customTypingIndicatorBuilder !=
                                null
                            ? widget.typingIndicatorOptions!
                                .customTypingIndicatorBuilder!(
                                context: context,
                                bubbleAlignment: widget.bubbleRtlAlignment,
                                options: widget.typingIndicatorOptions!,
                                indicatorOnScrollStatus:
                                    _indicatorOnScrollStatus,
                              )
                            : widget.typingIndicatorOptions
                                    ?.customTypingIndicator ??
                                TypingIndicator(
                                  bubbleAlignment: widget.bubbleRtlAlignment,
                                  options: widget.typingIndicatorOptions!,
                                  showIndicator: (widget.typingIndicatorOptions!
                                          .typingUsers.isNotEmpty &&
                                      !_indicatorOnScrollStatus),
                                ))
                        : const SizedBox.shrink(),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.only(bottom: 4),
                  sliver: SliverAnimatedList(
                    findChildIndexCallback: (Key key) {
                      if (key is ValueKey<Object>) {
                        final newIndex = widget.items.indexWhere(
                          (v) => _valueKeyForItem(v) == key,
                        );
                        if (newIndex != -1) {
                          return newIndex;
                        }
                      }
                      return null;
                    },
                    initialItemCount: widget.items.length,
                    key: _listKey,
                    itemBuilder: (_, index, animation) =>
                        _newMessageBuilder(index, animation),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.only(
                    top: 16 +
                        (widget.useTopSafeAreaInset
                            ? MediaQuery.of(context).padding.top
                            : 0),
                  ),
                  sliver: SliverToBoxAdapter(
                    child: SizeTransition(
                      axisAlignment: 1,
                      sizeFactor: _animation,
                      child: Center(
                        child: Container(
                          alignment: Alignment.center,
                          height: 32,
                          width: 32,
                          child: SizedBox(
                            height: 16,
                            width: 16,
                            child: _isNextPageLoading
                                ? CircularProgressIndicator(
                                    backgroundColor: Colors.transparent,
                                    strokeWidth: 1.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      InheritedChatTheme.of(context)
                                          .theme
                                          .primaryColor,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
      );
}
