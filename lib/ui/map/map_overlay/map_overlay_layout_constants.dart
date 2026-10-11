/// Bottom padding while the attribution links are hidden.
const double kMapBottomActionRowCollapsedPadding = 24;

/// Bottom padding while the narrow attribution link row is visible.
const double kMapBottomActionRowExpandedPadding = 36;

/// Keeps important controls clear of the rubber grips used by common bicycle
/// phone holders.
const double kMapHorizontalHolderClearance = 28;

/// Default width/height of [MapOverlayButton].
const double kMapOverlayControlSize = 48;

/// Vertical gap between the bottom of the side control column and the top of
/// the bottom action row.
const double kMapGapSideColumnAboveBottomBar = 64;

/// Keeps the whole side control column above the measured navigation panel.
double navigationPanelSideControlsOffset(double panelHeight) =>
    (panelHeight - kMapGapSideColumnAboveBottomBar + 8)
        .clamp(0.0, double.infinity)
        .toDouble();
