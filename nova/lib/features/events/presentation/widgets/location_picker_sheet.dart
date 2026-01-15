// Widget: LocationPickerSheet
// Feature: Maps integration for event locations
// Purpose: Bottom sheet for searching and selecting locations using Nominatim
//
// Features:
// - Search with debounce (500ms)
// - Shows location suggestions from OpenStreetMap Nominatim
// - Returns location name with coordinates

import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_radius.dart';
import '../../../../core/theme/nova_typography.dart';
import '../../data/services/nominatim_service.dart';

/// Result from location picker (with coordinates)
class LocationPickerResult {
  final String name;
  final double latitude;
  final double longitude;
  final String? placeId;
  final String? address;

  LocationPickerResult({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.placeId,
    this.address,
  });
}

/// Bottom sheet for searching and selecting locations
class LocationPickerSheet extends StatefulWidget {
  /// Current location text (if any)
  final String? currentLocation;

  /// Callback when location is selected from Maps (with coordinates)
  final void Function(LocationPickerResult result)? onLocationSelected;

  /// Callback when location is entered manually (without coordinates)
  final void Function(String locationName)? onManualLocationEntered;

  /// Callback when location is cleared
  final VoidCallback? onLocationCleared;

  const LocationPickerSheet({
    super.key,
    this.currentLocation,
    this.onLocationSelected,
    this.onManualLocationEntered,
    this.onLocationCleared,
  });

  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<LocationPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  final NominatimService _nominatimService = NominatimService();

  List<NominatimPlace> _results = [];
  bool _isLoading = false;
  String? _error;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    if (widget.currentLocation != null) {
      _searchController.text = widget.currentLocation!;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    _nominatimService.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();

    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _isLoading = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Debounce 500ms to respect Nominatim rate limit
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final results = await _nominatimService.search(query);
        if (mounted) {
          setState(() {
            _results = results;
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _error = 'Errore nella ricerca';
            _isLoading = false;
          });
        }
      }
    });
  }

  void _selectPlace(NominatimPlace place) {
    final result = LocationPickerResult(
      name: place.shortName,
      latitude: place.lat,
      longitude: place.lon,
      placeId: place.placeId,
      address: place.address,
    );
    widget.onLocationSelected?.call(result);
    Navigator.pop(context);
  }

  void _clearLocation() {
    widget.onLocationCleared?.call();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: NovaColors.border(context),
              borderRadius: NovaRadius.circularXxs,
            ),
          ),

          // Title and clear button
          Padding(
            padding: EdgeInsets.symmetric(horizontal: NovaSpacing.l),
            child: Row(
              children: [
                Text(
                  'Cerca luogo',
                  style: NovaTypography.headingSmall.copyWith(
                    color: NovaColors.textPrimary(context),
                  ),
                ),
                const Spacer(),
                if (widget.currentLocation != null)
                  TextButton.icon(
                    onPressed: _clearLocation,
                    icon: Icon(
                      Icons.clear,
                      size: 16,
                      color: NovaColors.error(context),
                    ),
                    label: Text(
                      'Rimuovi',
                      style: NovaTypography.bodySmall.copyWith(
                        color: NovaColors.error(context),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          SizedBox(height: NovaSpacing.m),

          // Search bar
          Padding(
            padding: EdgeInsets.symmetric(horizontal: NovaSpacing.l),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Es: Piazza Duomo, Milano',
                hintStyle: NovaTypography.bodyMedium.copyWith(
                  color: NovaColors.textSecondary(context),
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: 20,
                  color: NovaColors.textSecondary(context),
                ),
                suffixIcon: _isLoading
                    ? Padding(
                        padding: EdgeInsets.all(NovaSpacing.m),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: NovaColors.primary(context),
                          ),
                        ),
                      )
                    : _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear,
                              size: 18,
                              color: NovaColors.textSecondary(context),
                            ),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                            tooltip: 'Cancella',
                          )
                        : null,
                filled: true,
                fillColor: NovaColors.surface(context),
                border: OutlineInputBorder(
                  borderRadius: NovaRadius.circularM,
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: NovaRadius.circularM,
                  borderSide: BorderSide(color: NovaColors.border(context)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: NovaRadius.circularM,
                  borderSide: BorderSide(
                    color: NovaColors.primary(context),
                    width: 2,
                  ),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: NovaSpacing.m,
                  vertical: NovaSpacing.m,
                ),
              ),
              style: NovaTypography.bodyMedium,
            ),
          ),

          SizedBox(height: NovaSpacing.m),

          // Info text
          Padding(
            padding: EdgeInsets.symmetric(horizontal: NovaSpacing.l),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: NovaColors.textTertiary(context),
                ),
                SizedBox(width: NovaSpacing.xs),
                Expanded(
                  child: Text(
                    'Cerca un indirizzo per permettere agli utenti di aprirlo in Maps',
                    style: NovaTypography.bodySmall.copyWith(
                      color: NovaColors.textTertiary(context),
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: NovaSpacing.m),

          // Manual entry button (when user has typed something)
          if (_searchController.text.trim().isNotEmpty && !_isLoading)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: NovaSpacing.l),
              child: _buildManualEntryButton(),
            ),

          if (_searchController.text.trim().isNotEmpty && !_isLoading)
            SizedBox(height: NovaSpacing.s),

          // Results list or empty state
          Expanded(
            child: _buildResultsContent(scrollController),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsContent(ScrollController scrollController) {
    // Error state
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: NovaColors.error(context),
            ),
            SizedBox(height: NovaSpacing.m),
            Text(
              _error!,
              style: NovaTypography.bodyMedium.copyWith(
                color: NovaColors.textSecondary(context),
              ),
            ),
          ],
        ),
      );
    }

    // Empty state
    if (_results.isEmpty && !_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.place_outlined,
              size: 48,
              color: NovaColors.textTertiary(context),
            ),
            SizedBox(height: NovaSpacing.m),
            Text(
              _searchController.text.isEmpty
                  ? 'Cerca un luogo'
                  : 'Nessun risultato',
              style: NovaTypography.bodyMedium.copyWith(
                color: NovaColors.textSecondary(context),
              ),
            ),
          ],
        ),
      );
    }

    // Results list
    return ListView.builder(
      controller: scrollController,
      itemCount: _results.length,
      padding: EdgeInsets.symmetric(horizontal: NovaSpacing.s),
      itemBuilder: (context, index) {
        final place = _results[index];
        return _buildPlaceTile(place);
      },
    );
  }

  /// Button to use manually entered location text (without coordinates)
  Widget _buildManualEntryButton() {
    final text = _searchController.text.trim();

    return InkWell(
      onTap: () => _useManualLocation(text),
      borderRadius: NovaRadius.circularM,
      child: Container(
        padding: EdgeInsets.all(NovaSpacing.m),
        decoration: BoxDecoration(
          color: NovaColors.surface(context),
          borderRadius: NovaRadius.circularM,
          border: Border.all(
            color: NovaColors.primary(context).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: NovaColors.warning(context).withValues(alpha: 0.1),
                borderRadius: NovaRadius.circularS,
              ),
              child: Icon(
                Icons.edit_location_alt_outlined,
                color: NovaColors.warning(context),
                size: 20,
              ),
            ),
            SizedBox(width: NovaSpacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Usa "$text"',
                    style: NovaTypography.bodyMedium.copyWith(
                      color: NovaColors.textPrimary(context),
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Inserisci manualmente senza Maps',
                    style: NovaTypography.bodySmall.copyWith(
                      color: NovaColors.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: NovaColors.textTertiary(context),
            ),
          ],
        ),
      ),
    );
  }

  /// Use manually entered location (without coordinates)
  void _useManualLocation(String locationName) {
    widget.onManualLocationEntered?.call(locationName);
    Navigator.pop(context);
  }

  Widget _buildPlaceTile(NominatimPlace place) {
    return ListTile(
      onTap: () => _selectPlace(place),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: NovaColors.primary(context).withValues(alpha: 0.1),
          borderRadius: NovaRadius.circularS,
        ),
        child: Icon(
          Icons.place,
          color: NovaColors.primary(context),
          size: 20,
        ),
      ),
      title: Text(
        place.shortName,
        style: NovaTypography.bodyMedium.copyWith(
          color: NovaColors.textPrimary(context),
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: place.address != null
          ? Text(
              place.address!,
              style: NovaTypography.bodySmall.copyWith(
                color: NovaColors.textSecondary(context),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 14,
        color: NovaColors.textTertiary(context),
      ),
    );
  }
}
