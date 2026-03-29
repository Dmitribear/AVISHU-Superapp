import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../../shared/i18n/app_localization.dart';
import '../../../../shared/widgets/avishu_button.dart';
import '../../domain/enums/product_status.dart';
import '../../domain/models/product_model.dart';

class FranchiseeProductStudioView extends StatefulWidget {
  final AppLanguage language;
  final List<ProductModel> products;
  final VoidCallback onCreateProduct;
  final ValueChanged<ProductModel> onEditProduct;

  const FranchiseeProductStudioView({
    super.key,
    required this.language,
    required this.products,
    required this.onCreateProduct,
    required this.onEditProduct,
  });

  @override
  State<FranchiseeProductStudioView> createState() =>
      _FranchiseeProductStudioViewState();
}

class _FranchiseeProductStudioViewState
    extends State<FranchiseeProductStudioView> {
  ProductStatus? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final visibleProducts = widget.products.where((product) {
      if (_statusFilter == null) {
        return true;
      }
      return product.status == _statusFilter;
    }).toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _surfaceCard(
          backgroundColor: AppColors.black,
          borderColor: AppColors.black,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(
                  widget.language,
                  ru: 'PRODUCT STUDIO',
                  en: 'PRODUCT STUDIO',
                  kk: 'PRODUCT STUDIO',
                ),
                style: AppTypography.eyebrow.copyWith(
                  color: AppColors.surfaceDim,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                tr(
                  widget.language,
                  ru: 'КАТАЛОГ ПОД ВАШИМ КОНТРОЛЕМ',
                  en: 'THE CATALOG UNDER YOUR CONTROL',
                  kk: 'КАТАЛОГ СІЗДІҢ БАҚЫЛАУЫҢЫЗДА',
                ),
                style: Theme.of(
                  context,
                ).textTheme.headlineMedium?.copyWith(color: AppColors.white),
              ),
              const SizedBox(height: 12),
              Text(
                tr(
                  widget.language,
                  ru: 'Меняйте цену, скрывайте размеры, переводите модель в наличие или предзаказ и добавляйте новые товары в той же визуальной системе AVISHU.',
                  en: 'Update price, hide sizes, switch between in-stock and preorder, and add new products in the same AVISHU visual system.',
                  kk: 'Бағаны өзгертіңіз, өлшемдерді жасырыңыз, қолда бар немесе предзаказ күйіне ауыстырыңыз және жаңа тауарларды AVISHU визуал жүйесінде қосыңыз.',
                ),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.surfaceHighest,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AvishuButton(
          text: tr(
            widget.language,
            ru: 'ДОБАВИТЬ НОВЫЙ ТОВАР',
            en: 'ADD NEW PRODUCT',
            kk: 'ЖАҢА ТАУАР ҚОСУ',
          ),
          expanded: true,
          variant: AvishuButtonVariant.filled,
          icon: Icons.add,
          onPressed: widget.onCreateProduct,
        ),
        const SizedBox(height: 12),
        Text(
          tr(widget.language, ru: 'СТАТУС', en: 'STATUS', kk: 'КҮЙ'),
          style: AppTypography.eyebrow,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _filterPill(
              label: tr(widget.language, ru: 'ВСЕ', en: 'ALL', kk: 'БАРЛЫҒЫ'),
              selected: _statusFilter == null,
              onTap: () => setState(() => _statusFilter = null),
            ),
            ...ProductStatus.values.map(
              (status) => _filterPill(
                label: productStatusLabel(widget.language, status),
                selected: _statusFilter == status,
                onTap: () => setState(() => _statusFilter = status),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (visibleProducts.isEmpty)
          _surfaceCard(
            child: Text(
              tr(
                widget.language,
                ru: 'Под выбранный фильтр пока нет товаров.',
                en: 'No products match the selected filter yet.',
                kk: 'Таңдалған сүзгіге сай тауарлар әлі жоқ.',
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ...visibleProducts.map(
          (product) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _FranchiseeProductCard(
              language: widget.language,
              product: product,
              onTap: () => widget.onEditProduct(product),
            ),
          ),
        ),
      ],
    );
  }

  Widget _filterPill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.black : AppColors.surfaceLowest,
          border: Border.all(color: AppColors.black),
        ),
        child: Text(
          label.toUpperCase(),
          style: AppTypography.button.copyWith(
            color: selected ? AppColors.white : AppColors.black,
          ),
        ),
      ),
    );
  }
}

class _FranchiseeProductCard extends StatelessWidget {
  final AppLanguage language;
  final ProductModel product;
  final VoidCallback onTap;

  const _FranchiseeProductCard({
    required this.language,
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final availableSizeCount = product.sizes
        .where(product.isSizeAvailable)
        .length;

    return InkWell(
      onTap: onTap,
      child: _surfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 84,
                  height: 108,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: product.coverImage.isEmpty
                      ? const Icon(Icons.image_outlined, color: AppColors.grey)
                      : Image.network(
                          product.coverImage,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.image_not_supported_outlined,
                              color: AppColors.grey,
                            );
                          },
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${product.category} / ${product.silhouette}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          infoChip(
                            productStatusLabel(language, product.status),
                          ),
                          infoChip(
                            product.isInStock
                                ? tr(
                                    language,
                                    ru: 'В наличии',
                                    en: 'In Stock',
                                    kk: 'Қоймада бар',
                                  )
                                : product.isPreorderAvailable
                                ? tr(
                                    language,
                                    ru: 'Предзаказ',
                                    en: 'Preorder',
                                    kk: 'Предзаказ',
                                  )
                                : tr(
                                    language,
                                    ru: 'Нет в наличии',
                                    en: 'Out of Stock',
                                    kk: 'Қолжетімсіз',
                                  ),
                          ),
                          infoChip(
                            tr(
                              language,
                              ru: '$availableSizeCount / ${product.sizes.length} размеров',
                              en: '$availableSizeCount / ${product.sizes.length} sizes',
                              kk: '$availableSizeCount / ${product.sizes.length} өлшем',
                            ),
                          ),
                          infoChip(
                            tr(
                              language,
                              ru: '${product.gallery.length} фото',
                              en: '${product.gallery.length} photos',
                              kk: '${product.gallery.length} фото',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formatStudioPrice(product.price),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              product.shortDescription,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text(
              tr(
                language,
                ru: 'ОТКРЫТЬ РЕДАКТОР',
                en: 'OPEN EDITOR',
                kk: 'РЕДАКТОРДЫ АШУ',
              ),
              style: AppTypography.button,
            ),
          ],
        ),
      ),
    );
  }
}

Widget studioSurfaceCard({
  required Widget child,
  Color backgroundColor = AppColors.surfaceLowest,
  Color borderColor = AppColors.outlineVariant,
}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: backgroundColor,
      border: Border.all(color: borderColor),
    ),
    child: child,
  );
}

Widget _surfaceCard({
  required Widget child,
  Color backgroundColor = AppColors.surfaceLowest,
  Color borderColor = AppColors.outlineVariant,
}) {
  return studioSurfaceCard(
    child: child,
    backgroundColor: backgroundColor,
    borderColor: borderColor,
  );
}

Widget infoChip(String label) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.surfaceLow,
      border: Border.all(color: AppColors.outlineVariant),
    ),
    child: Text(
      label.toUpperCase(),
      style: AppTypography.code.copyWith(fontSize: 10),
    ),
  );
}

String productStatusLabel(AppLanguage language, ProductStatus status) {
  return switch (status) {
    ProductStatus.active => tr(
      language,
      ru: 'Активен',
      en: 'Active',
      kk: 'Белсенді',
    ),
    ProductStatus.draft => tr(
      language,
      ru: 'Черновик',
      en: 'Draft',
      kk: 'Нобай',
    ),
    ProductStatus.archived => tr(
      language,
      ru: 'Архив',
      en: 'Archived',
      kk: 'Архив',
    ),
  };
}

String formatStudioPrice(double price) {
  return '${price.toStringAsFixed(0)} KZT';
}
