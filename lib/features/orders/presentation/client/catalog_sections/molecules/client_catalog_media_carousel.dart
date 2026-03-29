import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../../core/theme/colors.dart';
import '../../../../../../core/theme/typography.dart';

class ClientCatalogMediaCarousel extends StatefulWidget {
  final List<String> imageUrls;
  final double aspectRatio;
  final Widget leadingChip;
  final Widget? trailingChip;
  final bool isFavorite;
  final VoidCallback onFavoriteTap;

  const ClientCatalogMediaCarousel({
    super.key,
    required this.imageUrls,
    required this.aspectRatio,
    required this.leadingChip,
    required this.trailingChip,
    required this.isFavorite,
    required this.onFavoriteTap,
  });

  @override
  State<ClientCatalogMediaCarousel> createState() =>
      _ClientCatalogMediaCarouselState();
}

class _ClientCatalogMediaCarouselState
    extends State<ClientCatalogMediaCarousel> {
  late final PageController _pageController;
  int _selectedImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: Stack(
        children: [
          Positioned.fill(
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.imageUrls.length,
              onPageChanged: (index) {
                if (_selectedImageIndex == index) {
                  return;
                }
                setState(() => _selectedImageIndex = index);
              },
              itemBuilder: (context, index) {
                return _networkProductImage(
                  widget.imageUrls[index],
                  fit: BoxFit.cover,
                );
              },
            ),
          ),
          Positioned(top: 12, left: 12, child: widget.leadingChip),
          if (widget.trailingChip != null)
            Positioned(top: 12, right: 12, child: widget.trailingChip!),
          Positioned(
            bottom: 12,
            right: 12,
            child: InkWell(
              onTap: widget.onFavoriteTap,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceLowest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.isFavorite
                      ? Icons.favorite
                      : Icons.favorite_border_outlined,
                  size: 18,
                ),
              ),
            ),
          ),
          if (widget.imageUrls.length > 1)
            Positioned(
              bottom: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                color: AppColors.black,
                child: Text(
                  '${_selectedImageIndex + 1} / ${widget.imageUrls.length}',
                  style: AppTypography.code.copyWith(
                    color: AppColors.white,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Widget _networkProductImage(String url, {BoxFit fit = BoxFit.cover}) {
  final imageUri = Uri.tryParse(url);
  final isDirectWebp = (imageUri?.path.toLowerCase() ?? '').endsWith('.webp');
  if (isDirectWebp) {
    return FutureBuilder<Uint8List>(
      future: _loadImageBytes(url),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _productImagePlaceholder(
            child: const Center(
              child: CircularProgressIndicator(
                color: Colors.black,
                strokeWidth: 2,
              ),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return _productImagePlaceholder(
            child: const Center(
              child: Icon(
                Icons.image_not_supported_outlined,
                color: AppColors.grey,
              ),
            ),
          );
        }

        return Image.memory(
          snapshot.data!,
          fit: fit,
          errorBuilder: (context, error, stackTrace) {
            return _productImagePlaceholder(
              child: const Center(
                child: Icon(
                  Icons.image_not_supported_outlined,
                  color: AppColors.grey,
                ),
              ),
            );
          },
        );
      },
    );
  }

  return Image.network(
    url,
    fit: fit,
    loadingBuilder: (context, child, progress) {
      if (progress == null) {
        return child;
      }

      return _productImagePlaceholder(
        child: const Center(
          child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
        ),
      );
    },
    errorBuilder: (context, error, stackTrace) {
      return _productImagePlaceholder(
        child: const Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            color: AppColors.grey,
          ),
        ),
      );
    },
  );
}

Future<Uint8List> _loadImageBytes(String url) async {
  final bundle = NetworkAssetBundle(Uri.parse(url));
  final data = await bundle.load(url);
  return data.buffer.asUint8List();
}

Widget _productImagePlaceholder({required Widget child}) {
  return Container(color: AppColors.surfaceHigh, child: child);
}
