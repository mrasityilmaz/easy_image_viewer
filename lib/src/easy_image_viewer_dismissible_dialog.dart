import 'package:dots_indicator/dots_indicator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:page_view_dot_indicator/page_view_dot_indicator.dart';

import 'easy_image_provider.dart';
import 'easy_image_view_pager.dart';

/// An internal widget that is used to hold a state to activate/deactivate the ability to
/// swipe-to-dismiss. This needs to be tied to the zoom scale of the current image, since
/// the user needs to be able to pan around on a zoomed-in image without triggering the
/// swipe-to-dismiss gesture.
class EasyImageViewerDismissibleDialog extends StatefulWidget {
  final EasyImageProvider imageProvider;
  final bool immersive;
  final void Function(int)? onPageChanged;
  final void Function(int)? onViewerDismissed;
  final bool useSafeArea;
  final bool swipeDismissible;
  final Color backgroundColor;
  final String closeButtonTooltip;
  final Color closeButtonColor;
  final bool showBottomDotsAndPageChanger;

  /// Refer to [showImageViewerPager] for the arguments
  const EasyImageViewerDismissibleDialog(this.imageProvider,
      {Key? key,
      this.immersive = true,
      this.onPageChanged,
      this.onViewerDismissed,
      this.useSafeArea = false,
      this.swipeDismissible = false,
      required this.backgroundColor,
      required this.closeButtonTooltip,
      required this.closeButtonColor, required this.showBottomDotsAndPageChanger})
      : super(key: key);

  @override
  State<EasyImageViewerDismissibleDialog> createState() => _EasyImageViewerDismissibleDialogState();
}

class _EasyImageViewerDismissibleDialogState extends State<EasyImageViewerDismissibleDialog> {
  /// This is used to either activate or deactivate the ability to swipe-to-dismissed, based on
  /// whether the current image is zoomed in (scale > 0) or not.
  DismissDirection _dismissDirection = DismissDirection.down;
  void Function()? _internalPageChangeListener;
  late final PageController _pageController;
  late final ListenableController _listenableController;

  static const _kDuration = Duration(milliseconds: 300);
  static const _kCurve = Curves.ease;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.imageProvider.initialIndex);
    _listenableController = ListenableController(
      _pageController,
    );
    if (widget.onPageChanged != null) {
      _internalPageChangeListener = () {
        widget.onPageChanged!(_pageController.page?.round() ?? 0);
      };
      _pageController.addListener(_internalPageChangeListener!);
    }
  }

  @override
  void dispose() {
    if (_internalPageChangeListener != null) {
      _pageController.removeListener(_internalPageChangeListener!);
    }
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final popScopeAwareDialog = WillPopScope(
        onWillPop: () async {
          _handleDismissal();
          return true;
        },
        child: Dialog(
            backgroundColor: widget.backgroundColor,
            insetPadding: const EdgeInsets.all(0),
            // We set the shape here to ensure no rounded corners allow any of the
            // underlying view to show. We want the whole background to be covered.
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: <Widget>[
              EasyImageViewPager(
                  easyImageProvider: widget.imageProvider,
                  pageController: _pageController,
                  onScaleChanged: (scale) {
                    setState(() {
                      _dismissDirection = scale <= 1.0 ? DismissDirection.down : DismissDirection.none;
                    });
                  }),
              Positioned(
                top: 5,
                right: 5,
                child: SafeArea(
                  child: Container(
                    decoration: BoxDecoration(color: Colors.white.withOpacity(.2), shape: BoxShape.circle),
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      color: widget.closeButtonColor,
                      tooltip: widget.closeButtonTooltip,
                      onPressed: () {
                        Navigator.of(context).pop();
                        _handleDismissal();
                      },
                    ),
                  ),
                ),
              ),
              if(widget.showBottomDotsAndPageChanger)
                SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: ValueListenableBuilder(
                      valueListenable: _listenableController,
                      builder: (BuildContext context, double currentPage, Widget? child) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: IconButton(
                                  splashRadius: 20,
                                  onPressed: () {
                                    _pageController.animateToPage(currentPage > 0 ? currentPage.toInt() - 1 : 0,
                                        duration: _kDuration, curve: _kCurve);
                                  },
                                  icon: Icon(
                                    Icons.adaptive.arrow_back_rounded,
                                    color: Colors.white,
                                  )),
                            ),
                            if (_pageController.hasClients)
                              Container(
                                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .35),
                                  decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10), color: Colors.white.withOpacity(.2)),
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                                  child: PageViewDotIndicator(
                                    currentItem: currentPage.toInt(),
                                    count: widget.imageProvider.imageCount,
                                    unselectedColor: Colors.black26,
                                    selectedColor: Theme.of(context).primaryColor,
                                    size: const Size(18, 9.0),
                                    unselectedSize: const Size.square(9.0),
                                    duration: const Duration(milliseconds: 200),
                                    margin: const EdgeInsets.symmetric(horizontal: 8),
                                    padding: EdgeInsets.zero,
                                    alignment: Alignment.center,
                                    fadeEdges: true,
                                  )),
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: IconButton(
                                  splashRadius: 20,
                                  onPressed: () {
                                    final lastPage = widget.imageProvider.imageCount - 1;
                                    _pageController.animateToPage(
                                        currentPage < lastPage ? currentPage.toInt() + 1 : lastPage,
                                        duration: _kDuration,
                                        curve: _kCurve);
                                  },
                                  icon: Icon(
                                    Icons.adaptive.arrow_forward_rounded,
                                    color: Colors.white,
                                  )),
                            )
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ])));

    if (widget.swipeDismissible) {
      return Dismissible(
          direction: _dismissDirection,
          resizeDuration: null,
          confirmDismiss: (dir) async {
            return true;
          },
          onDismissed: (_) {
            Navigator.of(context).pop();

            _handleDismissal();
          },
          key: const Key('dismissible_easy_image_viewer_dialog'),
          child: popScopeAwareDialog);
    } else {
      return popScopeAwareDialog;
    }
  }

  // Internal function to be called whenever the dialog
  // is dismissed, whether through the Android back button,
  // through the "x" close button, or through swipe-to-dismiss.
  void _handleDismissal() {
    if (widget.onViewerDismissed != null) {
      widget.onViewerDismissed!(_pageController.page?.round() ?? 0);
    }

    if (widget.immersive) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    if (_internalPageChangeListener != null) {
      _pageController.removeListener(_internalPageChangeListener!);
    }
  }
}

class ListenableController extends ValueListenable<double> {
  final PageController pageController;

  ListenableController(this.pageController);

  @override
  void addListener(listener) {
    pageController.addListener(listener);
  }

  @override
  void removeListener(listener) {
    pageController.removeListener(listener);
  }

  @override
  double get value => pageController.page ?? pageController.initialPage.toDouble();
}
