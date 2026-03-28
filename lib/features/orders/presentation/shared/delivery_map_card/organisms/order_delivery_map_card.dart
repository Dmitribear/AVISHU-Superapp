import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../../../core/theme/colors.dart';
import '../../../../../../core/theme/typography.dart';
import '../atoms/delivery_courier_marker.dart';
import '../atoms/delivery_map_attribution.dart';
import '../atoms/delivery_map_progress_bar.dart';
import '../atoms/delivery_map_tag.dart';
import '../delivery_map_palette.dart';
import '../molecules/delivery_map_marker_chip.dart';
import '../molecules/delivery_map_metric_row.dart';

class OrderDeliveryMapCard extends StatefulWidget {
  final String sectionLabel;
  final String badgeLabel;
  final String statusLabel;
  final String statusValue;
  final String etaLabel;
  final String etaValue;
  final String locationLabel;
  final String locationValue;
  final String amountLabel;
  final String amountValue;
  final String helperText;
  final String footerLabel;
  final String modeLabel;
  final String cityLabel;
  final String originLabel;
  final String destinationLabel;
  final double progress;
  final bool isLive;
  final bool isPickup;
  final bool isCompleted;
  final LatLng origin;
  final LatLng? destination;
  final LatLng? courier;
  final DateTime? updatedAt;

  const OrderDeliveryMapCard({
    super.key,
    required this.sectionLabel,
    required this.badgeLabel,
    required this.statusLabel,
    required this.statusValue,
    required this.etaLabel,
    required this.etaValue,
    required this.locationLabel,
    required this.locationValue,
    required this.amountLabel,
    required this.amountValue,
    required this.helperText,
    required this.footerLabel,
    required this.modeLabel,
    required this.cityLabel,
    required this.originLabel,
    required this.destinationLabel,
    required this.progress,
    required this.isLive,
    required this.isPickup,
    required this.isCompleted,
    required this.origin,
    this.destination,
    this.courier,
    this.updatedAt,
  });

  @override
  State<OrderDeliveryMapCard> createState() => _OrderDeliveryMapCardState();
}

class _OrderDeliveryMapCardState extends State<OrderDeliveryMapCard> {
  final MapController _mapController = MapController();
  bool _isMapReady = false;

  List<LatLng> get _mapPoints => <LatLng>[
    widget.origin,
    if (widget.destination != null) widget.destination!,
    if (widget.courier != null) widget.courier!,
  ];

  LatLng? get _courierPoint {
    if (widget.isPickup || widget.destination == null) {
      return null;
    }

    return widget.courier ?? widget.origin;
  }

  @override
  void didUpdateWidget(covariant OrderDeliveryMapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_routeFingerprint(oldWidget) != _routeFingerprint(widget)) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _syncCameraToPoints(),
      );
    }
  }

  String _routeFingerprint(OrderDeliveryMapCard card) {
    return [
      card.origin.latitude,
      card.origin.longitude,
      card.destination?.latitude ?? -999,
      card.destination?.longitude ?? -999,
      card.courier?.latitude ?? -999,
      card.courier?.longitude ?? -999,
    ].join('|');
  }

  void _syncCameraToPoints() {
    if (!_isMapReady) {
      return;
    }

    if (_mapPoints.length == 1) {
      _mapController.move(_mapPoints.first, 13.6);
      return;
    }

    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: _mapPoints,
        padding: const EdgeInsets.fromLTRB(54, 54, 54, 54),
        maxZoom: 15.6,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progressValue = widget.progress.clamp(0.0, 1.0);
    final showUpdatedBadge = widget.isLive && widget.updatedAt != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLowest,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(widget.sectionLabel, style: AppTypography.eyebrow),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: widget.isLive
                      ? AppColors.black
                      : AppColors.surfaceHigh,
                  border: Border.all(
                    color: widget.isLive
                        ? AppColors.black
                        : AppColors.outlineVariant,
                  ),
                ),
                child: Text(
                  widget.badgeLabel,
                  style: AppTypography.eyebrow.copyWith(
                    color: widget.isLive ? AppColors.white : AppColors.black,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AspectRatio(
            aspectRatio: 1.08,
            child: Container(
              decoration: BoxDecoration(
                color: DeliveryMapPalette.mapBackground,
                border: Border.all(color: AppColors.black),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRect(
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: widget.destination ?? widget.origin,
                          initialZoom: 13.2,
                          onMapReady: () {
                            _isMapReady = true;
                            _syncCameraToPoints();
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.avishu.avishu',
                            tileBuilder: darkModeTileBuilder,
                          ),
                          PolylineLayer(polylines: _buildPolylines()),
                          MarkerLayer(markers: _buildMarkers()),
                        ],
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: <Color>[
                              Colors.black.withValues(alpha: 0.34),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.4),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: DeliveryMapTag(
                      label: widget.modeLabel,
                      isFilled: true,
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: DeliveryMapTag(label: widget.cityLabel),
                  ),
                  if (widget.destination != null)
                    Positioned(
                      bottom: 12,
                      left: 12,
                      child: DeliveryMapTag(label: widget.originLabel),
                    ),
                  if (widget.destination != null)
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: DeliveryMapTag(label: widget.destinationLabel),
                    ),
                  if (showUpdatedBadge)
                    Positioned(
                      top: 48,
                      left: 12,
                      child: DeliveryMapTag(
                        label: 'LIVE ${_formatTime(widget.updatedAt!)}',
                      ),
                    ),
                  if (widget.destination != null)
                    Positioned(
                      right: 12,
                      bottom: 46,
                      child: DeliveryMapAttribution(
                        label: '${widget.footerLabel} / OSM',
                      ),
                    ),
                  if (widget.destination != null)
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 46,
                      child: DeliveryMapProgressBar(progress: progressValue),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          DeliveryMapMetricRow(
            label: widget.statusLabel,
            value: widget.statusValue,
          ),
          const SizedBox(height: 10),
          DeliveryMapMetricRow(label: widget.etaLabel, value: widget.etaValue),
          const SizedBox(height: 10),
          DeliveryMapMetricRow(
            label: widget.locationLabel,
            value: widget.locationValue,
          ),
          const SizedBox(height: 10),
          DeliveryMapMetricRow(
            label: widget.amountLabel,
            value: widget.amountValue,
          ),
          const SizedBox(height: 12),
          Text(
            widget.helperText,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.secondary),
          ),
        ],
      ),
    );
  }

  List<Polyline> _buildPolylines() {
    return <Polyline>[
      if (widget.destination != null)
        Polyline(
          points: <LatLng>[widget.origin, widget.destination!],
          strokeWidth: 6,
          color: DeliveryMapPalette.routeBase,
        ),
      if (_courierPoint != null)
        Polyline(
          points: <LatLng>[widget.origin, _courierPoint!],
          strokeWidth: 6,
          color: DeliveryMapPalette.routeGlow,
        ),
    ];
  }

  List<Marker> _buildMarkers() {
    if (widget.destination == null) {
      return const <Marker>[];
    }

    final markers = <Marker>[
      Marker(
        point: widget.origin,
        width: 148,
        height: 60,
        child: DeliveryMapMarkerChip(
          label: widget.originLabel,
          icon: widget.isPickup ? Icons.storefront : Icons.home_work_outlined,
          accentColor: AppColors.white,
        ),
      ),
      Marker(
        point: widget.destination!,
        width: 148,
        height: 68,
        child: DeliveryMapMarkerChip(
          label: widget.destinationLabel,
          icon: widget.isPickup
              ? Icons.inventory_2_outlined
              : Icons.location_on,
          accentColor: DeliveryMapPalette.destinationAccent,
          isHighlighted: true,
        ),
      ),
    ];

    if (_courierPoint != null) {
      markers.add(
        Marker(
          point: _courierPoint!,
          width: 86,
          height: 86,
          child: DeliveryCourierMarker(isCompleted: widget.isCompleted),
        ),
      );
    }

    return markers;
  }

  String _formatTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
