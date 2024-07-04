import 'package:flutter/material.dart';
import '../../flutter_chat_ui.dart';

class CustomStructureBuilder extends StatelessWidget {
  final ScrollController scrollController;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;
  final ScrollPhysics? scrollPhysics;
  final bool reverse;
  final Widget? bottomWidget;
  final TypingIndicatorOptions? typingIndicatorOptions;
  final bool indicatorOnScrollStatus;
  final BubbleRtlAlignment bubbleRtlAlignment;
  final bool isNextPageLoading;
  final Color primaryColor;
  final EdgeInsets padding;

  const CustomStructureBuilder({
    super.key,
    required this.scrollController,
    required this.keyboardDismissBehavior,
    this.scrollPhysics,
    required this.reverse,
    this.bottomWidget,
    this.typingIndicatorOptions,
    required this.indicatorOnScrollStatus,
    required this.bubbleRtlAlignment,
    required this.isNextPageLoading,
    required this.primaryColor,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) => CustomScrollView(
      controller: scrollController,
      keyboardDismissBehavior: keyboardDismissBehavior,
      physics: scrollPhysics,
      reverse: reverse,
      slivers: [
        if (bottomWidget != null)
          SliverToBoxAdapter(child: bottomWidget),
        SliverPadding(
          padding: padding,
          sliver: SliverToBoxAdapter(
            child: (typingIndicatorOptions!.typingUsers.isNotEmpty &&
                    !indicatorOnScrollStatus)
                ? (typingIndicatorOptions?.customTypingIndicatorBuilder !=
                        null
                    ? typingIndicatorOptions!.customTypingIndicatorBuilder!(
                        context: context,
                        bubbleAlignment: bubbleRtlAlignment,
                        options: typingIndicatorOptions!,
                        indicatorOnScrollStatus: indicatorOnScrollStatus,
                      )
                    : typingIndicatorOptions?.customTypingIndicator ??
                        TypingIndicator(
                          bubbleAlignment: bubbleRtlAlignment,
                          options: typingIndicatorOptions!,
                          showIndicator: (typingIndicatorOptions!
                                  .typingUsers.isNotEmpty &&
                              !indicatorOnScrollStatus),
                        ))
                : const SizedBox.shrink(),
          ),
        ),
        // Additional slivers can be added here as needed
        SliverPadding(
          padding: EdgeInsets.only(
            top: 16 + (padding.top),
          ),
          sliver: SliverToBoxAdapter(
            child: SizeTransition(
              axisAlignment: 1,
              sizeFactor: const AlwaysStoppedAnimation<double>(1), // Assuming a static animation for simplicity
              child: Center(
                child: Container(
                  alignment: Alignment.center,
                  height: 32,
                  width: 32,
                  child: SizedBox(
                    height: 16,
                    width: 16,
                    child: isNextPageLoading
                        ? CircularProgressIndicator(
                            backgroundColor: Colors.transparent,
                            strokeWidth: 1.5,
                            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                          )
                        : null,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
}