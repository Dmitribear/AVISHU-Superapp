import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';

class OrderDeliveryMapCard extends StatefulWidget {
  final String eyebrow;
  final String badge;
  final String statusLabel;
  final String statusValue;
  final String etaLabel;
  final String etaValue;
  final String locationLabel;
  final String locationValue;
  final String amountLabel;
  final String amountValue;
  final String note;
  final String footer;
  final String modeTag;
  final String cityTag;
  final String originLabel;
  final String destinationLabel;
  final double progress;
  final bool live;
  final bool pickup;
  final bool completed;
  final LatLng origin;
  final LatLng destination;
  final LatLng? courier;
  final DateTime? updatedAt;

  const OrderDeliveryMapCard({
    super.key,
    required this.eyebrow,
    required this.badge,
    required this.statusLabel,
    required this.statusValue,
    required this.etaLabel,
    required this.etaValue,
    required this.locationLabel,
    required this.locationValue,
    required this.amountLabel,
    required this.amountValue,
    required this.note,
    required this.footer,
    required this.modeTag,
    required this.cityTag,
    required this.originLabel,
    required this.destinationLabel,
    required this.progress,
    required this.live,
    required this.pickup,
    required this.completed,
    required this.origin,
    required this.destination,
    this.courier,
    this.updatedAt,
  });

  @override
  State<OrderDeliveryMapCard> createState() => _OrderDeliveryMapCardState();
}

class _OrderDeliveryMapCardState extends State<OrderDeliveryMapCard> {
  static const Color _mapBackground = Color(0xFF080B10);
  static const Color _routeBase = Color(0x40FFFFFF);
  static const Color _routeGlow = Color(0xFF74D8C9);
  static const Color _destinationAccent = Color(0xFFF4C46B);

  final MapController _mapController = MapController();
  bool _mapReady = false;

  List<LatLng> get _cameraPoints => <LatLng>[
    widget.origin,
    widget.destination,
    if (widget.courier != null) widget.courier!,
  ];

  LatLng? get _activeCourier {
    if (widget.pickup) {
      return null;
    }
    return widget.courier ?? widget.origin;
  }

  @override
  void didUpdateWidget(covariant OrderDeliveryMapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_signature(oldWidget) != _signature(widget)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitCamera());
    }
  }

  String _signature(OrderDeliveryMapCard card) {
    return [
      card.origin.latitude,
      card.origin.longitude,
      card.destination.latitude,
      card.destination.longitude,
      card.courier?.latitude ?? -999,
      card.courier?.longitude ?? -999,
    ].join('|');
  }

  void _fitCamera() {
    if (!_mapReady) {
      return;
    }

    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: _cameraPoints,
        padding: const EdgeInsets.fromLTRB(54, 54, 54, 54),
        maxZoom: 15.6,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final routeProgress = widget.progress.clamp(0.0, 1.0);
    final liveSync = widget.live && widget.updatedAt != null;

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
                child: Text(widget.eyebrow, style: AppTypography.eyebrow),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: widget.live ? AppColors.black : AppColors.surfaceHigh,
                  border: Border.all(
                    color: widget.live
                        ? AppColors.black
                        : AppColors.outlineVariant,
                  ),
                ),
                child: Text(
                  widget.badge,
                  style: AppTypography.eyebrow.copyWith(
                    color: widget.live ? AppColors.white : AppColors.black,
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
                color: _mapBackground,
                border: Border.all(color: AppColors.black),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRect(
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: widget.destination,
                          initialZoom: 13.2,
                          onMapReady: () {
                            _mapReady = true;
                            _fitCamera();
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.avishu.avishu',
                            tileBuilder: darkModeTileBuilder,
                          ),
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: <LatLng>[
                                  widget.origin,
                                  widget.destination,
                                ],
                                strokeWidth: 6,
                                color: _routeBase,
                              ),
                              if (_activeCourier != null)
                                Polyline(
                                  points: <LatLng>[
                                    widget.origin,
                                    _activeCourier!,
                                  ],
                                  strokeWidth: 6,
                                  color: _routeGlow,
                                ),
                            ],
                          ),
                          MarkerLayer(markers: _markers()),
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
                    child: _MapTag(label: widget.modeTag, filled: true),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: _MapTag(label: widget.cityTag),
                  ),
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: _MapTag(label: widget.originLabel),
                  ),
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: _MapTag(label: widget.destinationLabel),
                  ),
                  if (liveSync)
                    Positioned(
                      top: 48,
                      left: 12,
                      child: _MapTag(
                        label: 'LIVE ${_timeLabel(widget.updatedAt!)}',
                      ),
                    ),
                  Positioned(
                    right: 12,
                    bottom: 46,
                    child: _MapAttribution(label: '${widget.footer} / OSM'),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 46,
                    child: _MapProgressBar(progress: routeProgress),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _MapMetricRow(label: widget.statusLabel, value: widget.statusValue),
          const SizedBox(height: 10),
          _MapMetricRow(label: widget.etaLabel, value: widget.etaValue),
          const SizedBox(height: 10),
          _MapMetricRow(
            label: widget.locationLabel,
            value: widget.locationValue,
          ),
          const SizedBox(height: 10),
          _MapMetricRow(label: widget.amountLabel, value: widget.amountValue),
          const SizedBox(height: 12),
          Text(
            widget.note,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.secondary),
          ),
        ],
      ),
    );
  }

  List<Marker> _markers() {
    final markers = <Marker>[
      Marker(
        point: widget.origin,
        width: 88,
        height: 56,
        child: _MapMarkerChip(
          label: widget.originLabel,
          icon: widget.pickup ? Icons.storefront : Icons.home_work_outlined,
          accent: AppColors.white,
        ),
      ),
      Marker(
        point: widget.destination,
        width: 96,
        height: 64,
        child: _MapMarkerChip(
          label: widget.destinationLabel,
          icon: widget.pickup ? Icons.inventory_2_outlined : Icons.location_on,
          accent: _destinationAccent,
          emphasis: true,
        ),
      ),
    ];

    if (_activeCourier != null) {
      markers.add(
        Marker(
          point: _activeCourier!,
          width: 86,
          height: 86,
          child: _CourierMarker(completed: widget.completed),
        ),
      );
    }

    return markers;
  }

  String _timeLabel(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _MapMetricRow extends StatelessWidget {
  final String label;
  final String value;

  const _MapMetricRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label, style: AppTypography.eyebrow)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _MapTag extends StatelessWidget {
  final String label;
  final bool filled;

  const _MapTag({required this.label, this.filled = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: filled ? AppColors.black : Colors.black.withValues(alpha: 0.55),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: AppTypography.eyebrow.copyWith(color: AppColors.white),
      ),
    );
  }
}

class _MapProgressBar extends StatelessWidget {
  final double progress;

  const _MapProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        height: 6,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(999),
        ),
        child: FractionallySizedBox(
          widthFactor: progress.clamp(0.0, 1.0),
          alignment: Alignment.centerLeft,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF74D8C9),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapMarkerChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color accent;
  final bool emphasis;

  const _MapMarkerChip({
    required this.label,
    required this.icon,
    required this.accent,
    this.emphasis = false,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: emphasis ? 0.84 : 0.66),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.55)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: accent),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.eyebrow.copyWith(color: AppColors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _CourierMarker extends StatelessWidget {
  final bool completed;

  const _CourierMarker({required this.completed});

  @override
  Widget build(BuildContext context) {
    final haloColor = completed
        ? const Color(0x40F4C46B)
        : const Color(0x3374D8C9);
    final coreColor = completed
        ? const Color(0xFFF4C46B)
        : const Color(0xFF74D8C9);

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: haloColor, shape: BoxShape.circle),
          ),
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: coreColor,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.white, width: 3),
            ),
          ),
          Positioned(
            top: 4,
            child: Icon(
              Icons.local_shipping_rounded,
              size: 14,
              color: AppColors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapAttribution extends StatelessWidget {
  final String label;

  const _MapAttribution({required this.label});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Text(
          label,
          style: AppTypography.code.copyWith(
            color: AppColors.white.withValues(alpha: 0.86),
            fontSize: 9,
          ),
        ),
      ),
    );
  }
}
