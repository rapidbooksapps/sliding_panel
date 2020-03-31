part of sliding_panel;

class _PanelScrollPosition extends ScrollPositionWithSingleContext {
  VoidCallback _dragCancelled;
  final _PanelMetadata metadata;

  bool get shouldListScroll => pixels > 0.0;

  final _SlidingPanelState panel;

  _PanelScrollPosition({
    ScrollPhysics physics,
    ScrollContext context,
    double initPix = 0.0,
    bool keepScroll = true,
    ScrollPosition oldPos,
    this.metadata,
    this.panel,
  }) : super(
          physics: physics,
          context: context,
          initialPixels: initPix,
          keepScrollOffset: keepScroll,
          oldPosition: oldPos,
        );

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    return super.applyContentDimensions(
        minScrollExtent - metadata.extraClosedHeight, maxScrollExtent + metadata.extraExpandedHeight);
  }

  @override
  void applyUserOffset(double delta) {
    // whenever dragged

    _dragPanel(
      panel,
      delta: delta,
      isGesture: false,
      shouldListScroll: shouldListScroll,
      dragFromBody: false,
      scrollContentSuper: () {
        super.applyUserOffset(delta);
      },
    );
  }

  @override
  Drag drag(DragStartDetails details, VoidCallback dragCancelCallback) {
    // like onDragStart

    _PanelAnimation.clear();

    _dragCancelled = dragCancelCallback;
    return super.drag(details, dragCancelCallback);
  }

  @override
  void goBallistic(double velocity) {
    // like onDragEnd
    if ((panel._controller.currentState == PanelState.closed) && (panel.widget.panelClosedOptions.detachDragging)) {
      super.goBallistic(velocity);
      return;
    }

    if (metadata._isBodyDrag.value) {
      // if it is dragged from body, let _dragPanel handle ALL the things...
      super.goBallistic(velocity);
      return;
    }

    if (!metadata.isDraggable) {
      super.goBallistic(velocity);
      return;
    }

    if (((velocity.abs() == 0.0) || (velocity < 0.0 && shouldListScroll) || (velocity > 0.0 && metadata.isExpanded)) &&
        (panel._controller.currentState != PanelState.indefinite)) {
      // when dragged and released slowly in middle OR at start with scrolling OR at end
      // and panel is not in-between
      super.goBallistic(velocity);
      return;
    }

    _dragCancelled?.call(); // must call
    _dragCancelled = null;

    if (metadata.snapping == PanelSnapping.disabled) {
      // no panel snapping, just scroll the panel
      _scrollPanel(
        this,
        velocity: velocity,
      );
    } else {
      // snap the panel

      if (!((panel._metadata.allowedDraggingTill.containsKey(PanelDraggingDirection.DOWN)) ||
          (panel._metadata.allowedDraggingTill.containsKey(PanelDraggingDirection.UP)))) {
        // no restriction
        double percent = ((metadata.totalHeight * metadata.snappingTriggerPercentage) / 100);

        percent = percent._safeClamp(0.0, 750.0);

        if (percent > 0.0) {
          if (velocity.abs() <= percent) {
            _scrollPanel(
              this,
              velocity: velocity,
            );
            return;
          }
        }
      }

      if ((velocity.abs() == 0.0) && (metadata.snapping == PanelSnapping.forced)) {
        if (velocity.isNegative)
          velocity = -0.1;
        else
          velocity = 0.1;
      }

      _PanelSnapData snapData = _PanelSnapData(
        scrollPos: this,
        dragVelocity: velocity,
        snapping: metadata.snapping,
      );

      snapData.prepareSnapping();

      if (snapData.shouldPanelSnap) {
        snapData.snapPanel();
        // Needed. Otherwise, it would stop interaction with panel by calling
        // 'drag' again and no interaction with panel will happen
        // after this snapping
        super.goBallistic(0.0);
      } else {
        super.goBallistic(velocity);
      }
    }
  }

  @override
  void dispose() {
    _PanelAnimation.clear();
    super.dispose();
  }
}

class _PanelScrollController extends ScrollController {
  final _PanelMetadata metadata;

  final _SlidingPanelState panel;

  _PanelScrollController({double initScrollOffset = 0.0, this.metadata, this.panel})
      : super(initialScrollOffset: initScrollOffset);

  _PanelScrollPosition _scrollPosition;

  @override
  _PanelScrollPosition createScrollPosition(ScrollPhysics physics, ScrollContext context, ScrollPosition oldPosition) {
    _scrollPosition = _PanelScrollPosition(
//      physics: physics,
      physics: _PanelScrollableScrollPhysics(panel, parent: physics),
      context: context,
      oldPos: oldPosition,
      metadata: metadata,
      panel: panel,
    );
    return _scrollPosition;
  }
}

class _PanelScrollableScrollPhysics extends ScrollPhysics {
  final _SlidingPanelState panel;
  bool _done = false;

  /// Creates scroll physics that does not let the user scroll.
  _PanelScrollableScrollPhysics(this.panel, { ScrollPhysics parent })
      : super(parent: parent);

  @override
  _PanelScrollableScrollPhysics applyTo(ScrollPhysics ancestor) {
    return _PanelScrollableScrollPhysics(this.panel, parent: buildParent(ancestor));
  }

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) {
    if (panel._currentPanelState == PanelState.collapsed || panel._currentPanelState == PanelState.expanded) {
      _done = true;
    }
    if (panel._currentPanelState == PanelState.animating && !_done) {
      return false;
    }
    return parent.shouldAcceptUserOffset(position);
  }

  @override
  bool get allowImplicitScrolling {
    if (panel._currentPanelState == PanelState.collapsed || panel._currentPanelState == PanelState.expanded) {
      _done = true;
    }
    if (panel._currentPanelState == PanelState.animating && !_done) {
      return false;
    }
    return parent.allowImplicitScrolling;
  }
}