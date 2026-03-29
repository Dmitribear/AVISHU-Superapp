import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../../shared/i18n/app_localization.dart';
import '../../../../shared/widgets/avishu_button.dart';
import '../../domain/enums/product_status.dart';
import '../../domain/models/product_model.dart';
import 'franchisee_product_studio_view.dart';

class FranchiseeProductEditorView extends StatefulWidget {
  final AppLanguage language;
  final ProductModel? initialProduct;
  final bool isSaving;
  final ValueChanged<ProductModel> onSave;
  final VoidCallback onCancel;

  const FranchiseeProductEditorView({
    super.key,
    required this.language,
    required this.initialProduct,
    required this.isSaving,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<FranchiseeProductEditorView> createState() =>
      _FranchiseeProductEditorViewState();
}

class _FranchiseeProductEditorViewState
    extends State<FranchiseeProductEditorView> {
  static const _categoryOptions = <String>[
    'Верхняя одежда',
    'Кардиганы и кофты',
    'Костюмы',
    'База',
    'Брюки',
    'Юбки',
  ];
  static const _seasonOptions = <String>['Весна', 'Лето', 'Зима'];
  static const _sizeOptions = <String>[
    'XS',
    'S',
    'M',
    'L',
    'XL',
    '2XL',
    '3XL',
    '4XL',
    '5XL',
    '6XL',
  ];

  late final TextEditingController _nameController;
  late final TextEditingController _shortDescriptionController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late final TextEditingController _materialController;
  late final TextEditingController _silhouetteController;
  late final TextEditingController _colorsController;
  late final TextEditingController _galleryController;
  late final TextEditingController _atelierNoteController;
  late ProductStatus _status;
  late bool _isInStock;
  late bool _isPreorderAvailable;
  late bool _isNewArrival;
  late bool _isBaseCapsule;
  late String _selectedCategory;
  late String _selectedSeason;
  late Set<String> _selectedSizes;
  late Map<String, bool> _sizeAvailability;

  bool get _isEditing => widget.initialProduct != null;

  @override
  void initState() {
    super.initState();
    final product = widget.initialProduct;
    final sections = product?.sections ?? const <String>[];

    _nameController = TextEditingController(text: product?.name ?? '');
    _shortDescriptionController = TextEditingController(
      text: product?.shortDescription ?? '',
    );
    _descriptionController = TextEditingController(
      text: product?.description ?? '',
    );
    _priceController = TextEditingController(
      text: product == null ? '' : product.price.toStringAsFixed(0),
    );
    _materialController = TextEditingController(text: product?.material ?? '');
    _silhouetteController = TextEditingController(
      text: product?.silhouette ?? '',
    );
    _colorsController = TextEditingController(
      text: (product?.colors ?? const <String>[]).join(', '),
    );
    _galleryController = TextEditingController(
      text: (product?.gallery ?? const <String>[]).join('\n'),
    );
    _atelierNoteController = TextEditingController(
      text: product?.atelierNote ?? '',
    );
    _galleryController.addListener(_handleGalleryChanged);

    _status = product?.status ?? ProductStatus.active;
    _isInStock = product?.isInStock ?? true;
    _isPreorderAvailable = product?.isPreorderAvailable ?? false;
    _isNewArrival = sections.contains('Новинки');
    _isBaseCapsule = sections.contains('База') || product?.category == 'База';
    _selectedCategory = _resolvedCategory(product?.category);
    _selectedSeason = _resolvedSeason(sections);
    _selectedSizes = (product?.sizes ?? const <String>['S', 'M']).toSet();
    _sizeAvailability = <String, bool>{
      for (final size in _sizeOptions)
        size: _selectedSizes.contains(size)
            ? (product?.sizeAvailability[size] ?? true)
            : false,
    };
  }

  @override
  void dispose() {
    _galleryController.removeListener(_handleGalleryChanged);
    _nameController.dispose();
    _shortDescriptionController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _materialController.dispose();
    _silhouetteController.dispose();
    _colorsController.dispose();
    _galleryController.dispose();
    _atelierNoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        studioSurfaceCard(
          backgroundColor: AppColors.black,
          borderColor: AppColors.black,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(
                  widget.language,
                  ru: _isEditing ? 'РЕДАКТИРОВАНИЕ ТОВАРА' : 'НОВЫЙ ТОВАР',
                  en: _isEditing ? 'EDIT PRODUCT' : 'NEW PRODUCT',
                  kk: _isEditing ? 'ТАУАРДЫ ӨҢДЕУ' : 'ЖАҢА ТАУАР',
                ),
                style: AppTypography.eyebrow.copyWith(
                  color: AppColors.surfaceDim,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                tr(
                  widget.language,
                  ru: 'УПРАВЛЯЙТЕ ТОВАРОМ БЕЗ ВЫХОДА ИЗ AVISHU',
                  en: 'MANAGE THE PRODUCT WITHOUT LEAVING AVISHU',
                  kk: 'ТАУАРДЫ AVISHU-ДАН ШЫҚПАЙ БАСҚАРЫҢЫЗ',
                ),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: AppColors.white),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        studioSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _field(
                controller: _nameController,
                label: tr(
                  widget.language,
                  ru: 'Название товара',
                  en: 'Product Name',
                  kk: 'Тауар атауы',
                ),
              ),
              const SizedBox(height: 12),
              _field(
                controller: _priceController,
                label: tr(
                  widget.language,
                  ru: 'Цена, KZT',
                  en: 'Price, KZT',
                  kk: 'Бағасы, KZT',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 12),
              _field(
                controller: _materialController,
                label: tr(
                  widget.language,
                  ru: 'Материал',
                  en: 'Material',
                  kk: 'Материал',
                ),
              ),
              const SizedBox(height: 12),
              _field(
                controller: _silhouetteController,
                label: tr(
                  widget.language,
                  ru: 'Силуэт',
                  en: 'Silhouette',
                  kk: 'Силуэт',
                ),
              ),
              const SizedBox(height: 12),
              _field(
                controller: _shortDescriptionController,
                label: tr(
                  widget.language,
                  ru: 'Короткое описание',
                  en: 'Short Description',
                  kk: 'Қысқа сипаттама',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              _field(
                controller: _descriptionController,
                label: tr(
                  widget.language,
                  ru: 'Полное описание',
                  en: 'Full Description',
                  kk: 'Толық сипаттама',
                ),
                maxLines: 5,
              ),
              const SizedBox(height: 12),
              _field(
                controller: _colorsController,
                label: tr(
                  widget.language,
                  ru: 'Цвета через запятую',
                  en: 'Colors, comma-separated',
                  kk: 'Түстерді үтірмен бөліңіз',
                ),
              ),
              const SizedBox(height: 12),
              _field(
                controller: _galleryController,
                label: tr(
                  widget.language,
                  ru: 'Ссылки на фото, каждая с новой строки',
                  en: 'Photo URLs, one per line',
                  kk: 'Фото сілтемелері, әрқайсысы жаңа жолдан',
                ),
                maxLines: 5,
              ),
              if (_galleryPreviewUrls.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 112,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _galleryPreviewUrls.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      return _galleryPreviewTile(
                        imageUrl: _galleryPreviewUrls[index],
                        index: index,
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _field(
                controller: _atelierNoteController,
                label: tr(
                  widget.language,
                  ru: 'Примечание ателье',
                  en: 'Atelier Note',
                  kk: 'Ателье ескертпесі',
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: tr(
            widget.language,
            ru: 'КАТЕГОРИЯ И СЕЗОН',
            en: 'CATEGORY & SEASON',
            kk: 'САНАТ ЖӘНЕ МАУСЫМ',
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categoryOptions
                    .map(
                      (value) => _pill(
                        label: value,
                        selected: _selectedCategory == value,
                        onTap: () => setState(() => _selectedCategory = value),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _seasonOptions
                    .map(
                      (value) => _pill(
                        label: value,
                        selected: _selectedSeason == value,
                        onTap: () => setState(() => _selectedSeason = value),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _togglePill(
                    label: tr(
                      widget.language,
                      ru: 'Новинка',
                      en: 'New Arrival',
                      kk: 'Жаңа',
                    ),
                    value: _isNewArrival,
                    onChanged: (value) => setState(() => _isNewArrival = value),
                  ),
                  _togglePill(
                    label: tr(
                      widget.language,
                      ru: 'База',
                      en: 'Base Capsule',
                      kk: 'База',
                    ),
                    value: _isBaseCapsule,
                    onChanged: (value) =>
                        setState(() => _isBaseCapsule = value),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: tr(
            widget.language,
            ru: 'НАЛИЧИЕ И РАЗМЕРЫ',
            en: 'AVAILABILITY & SIZES',
            kk: 'ҚОЛЖЕТІМДІЛІК ЖӘНЕ ӨЛШЕМДЕР',
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _sizeOptions
                    .map(
                      (size) => _pill(
                        label: size,
                        selected: _selectedSizes.contains(size),
                        onTap: () => _toggleSize(size),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _selectedSizes
                    .map(
                      (size) => _togglePill(
                        label: size,
                        value: _sizeAvailability[size] ?? true,
                        onChanged: (value) {
                          setState(() {
                            _sizeAvailability[size] = value;
                          });
                        },
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _switchTile(
                      label: tr(
                        widget.language,
                        ru: 'В наличии',
                        en: 'In Stock',
                        kk: 'Қоймада бар',
                      ),
                      value: _isInStock,
                      onChanged: (value) => setState(() => _isInStock = value),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _switchTile(
                      label: tr(
                        widget.language,
                        ru: 'Предзаказ',
                        en: 'Preorder',
                        kk: 'Предзаказ',
                      ),
                      value: _isPreorderAvailable,
                      onChanged: (value) =>
                          setState(() => _isPreorderAvailable = value),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: tr(widget.language, ru: 'СТАТУС', en: 'STATUS', kk: 'КҮЙ'),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ProductStatus.values
                .map(
                  (value) => _pill(
                    label: productStatusLabel(widget.language, value),
                    selected: _status == value,
                    onTap: () => setState(() => _status = value),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: AvishuButton(
                text: tr(widget.language, ru: 'НАЗАД', en: 'BACK', kk: 'АРТҚА'),
                variant: AvishuButtonVariant.outline,
                onPressed: widget.isSaving ? null : widget.onCancel,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AvishuButton(
                text: tr(
                  widget.language,
                  ru: widget.isSaving ? 'СОХРАНЯЕМ' : 'СОХРАНИТЬ',
                  en: widget.isSaving ? 'SAVING' : 'SAVE',
                  kk: widget.isSaving ? 'САҚТАЛУДА' : 'САҚТАУ',
                ),
                variant: AvishuButtonVariant.filled,
                onPressed: widget.isSaving ? null : _submit,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _toggleSize(String size) {
    setState(() {
      if (_selectedSizes.contains(size)) {
        _selectedSizes.remove(size);
        _sizeAvailability[size] = false;
      } else {
        _selectedSizes.add(size);
        _sizeAvailability[size] = true;
      }
    });
  }

  void _handleGalleryChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  List<String> get _galleryPreviewUrls {
    return _splitMultiline(_galleryController.text);
  }

  void _submit() {
    final name = _nameController.text.trim();
    final price = double.tryParse(
      _priceController.text.replaceAll(',', '.').trim(),
    );
    final selectedSizes = _sizeOptions
        .where((size) => _selectedSizes.contains(size))
        .toList();
    final availableSizes = <String, bool>{
      for (final size in selectedSizes) size: _sizeAvailability[size] ?? true,
    };
    final gallery = _splitMultiline(_galleryController.text);
    final colors = _splitCommaSeparated(_colorsController.text);

    if (name.isEmpty || price == null || selectedSizes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              widget.language,
              ru: 'Заполните название, цену и хотя бы один размер.',
              en: 'Fill in the name, price, and at least one size.',
              kk: 'Атауын, бағасын және кемінде бір өлшемді толтырыңыз.',
            ),
          ),
        ),
      );
      return;
    }

    final now = DateTime.now();
    final existing = widget.initialProduct;
    final id = existing?.id ?? 'product-${now.millisecondsSinceEpoch}';
    final slug = existing?.slug ?? _slugFromName(name, fallback: id);
    final defaultColor = colors.isNotEmpty
        ? colors.first
        : (existing?.defaultColor ?? 'Black');
    final defaultSize = _resolveDefaultSize(
      preferredSize: existing?.defaultSize,
      sizes: selectedSizes,
      sizeAvailability: availableSizes,
    );

    widget.onSave(
      ProductModel(
        id: id,
        name: name,
        slug: slug,
        description: _descriptionController.text.trim(),
        shortDescription: _shortDescriptionController.text.trim(),
        category: _selectedCategory,
        material: _materialController.text.trim(),
        silhouette: _silhouetteController.text.trim(),
        atelierNote: _atelierNoteController.text.trim(),
        sections: _buildSections(),
        colors: colors,
        sizes: selectedSizes,
        defaultColor: defaultColor,
        defaultSize: defaultSize,
        specifications:
            existing?.specifications ??
            <ProductSpecEntry>[
              ProductSpecEntry(label: 'Category', value: _selectedCategory),
              ProductSpecEntry(
                label: 'Material',
                value: _materialController.text.trim(),
              ),
              ProductSpecEntry(
                label: 'Silhouette',
                value: _silhouetteController.text.trim(),
              ),
            ],
        care:
            existing?.care ??
            const <String>[
              'Handle with care according to the fabric composition.',
              'Store on a soft hanger or in a garment bag.',
            ],
        price: price,
        currency: existing?.currency ?? 'KZT',
        isInStock: _isInStock,
        sizeAvailability: availableSizes,
        coverImage: gallery.isNotEmpty
            ? gallery.first
            : (existing?.coverImage ?? ''),
        gallery: gallery,
        isPreorderAvailable: _isPreorderAvailable,
        defaultProductionDays: _isPreorderAvailable
            ? (existing?.defaultProductionDays ?? 4)
            : 0,
        status: _status,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      ),
    );
  }

  List<String> _buildSections() {
    final sections = <String>[
      if (_isNewArrival) 'Новинки',
      _selectedCategory,
      _selectedSeason,
      if (_isBaseCapsule && _selectedCategory != 'База') 'База',
    ];
    return sections.toSet().toList();
  }

  String _resolvedCategory(String? category) {
    if (category != null && _categoryOptions.contains(category)) {
      return category;
    }
    return _categoryOptions.first;
  }

  String _resolvedSeason(List<String> sections) {
    for (final season in _seasonOptions) {
      if (sections.contains(season)) {
        return season;
      }
    }
    return _seasonOptions.first;
  }

  String _resolveDefaultSize({
    required String? preferredSize,
    required List<String> sizes,
    required Map<String, bool> sizeAvailability,
  }) {
    if (preferredSize != null &&
        sizes.contains(preferredSize) &&
        (sizeAvailability[preferredSize] ?? true)) {
      return preferredSize;
    }
    for (final size in sizes) {
      if (sizeAvailability[size] ?? true) {
        return size;
      }
    }
    return sizes.first;
  }

  List<String> _splitCommaSeparated(String input) {
    return input
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
  }

  List<String> _splitMultiline(String input) {
    return input
        .split('\n')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
  }

  String _slugFromName(String name, {required String fallback}) {
    final normalized = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return normalized.isEmpty ? fallback : normalized;
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return studioSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.eyebrow),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _pill({
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

  Widget _togglePill({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: value ? AppColors.black : AppColors.surfaceLowest,
          border: Border.all(
            color: value ? AppColors.black : AppColors.outlineVariant,
          ),
        ),
        child: Text(
          label.toUpperCase(),
          style: AppTypography.button.copyWith(
            color: value ? AppColors.white : AppColors.black,
          ),
        ),
      ),
    );
  }

  Widget _switchTile({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.black,
            activeTrackColor: AppColors.surfaceDim,
          ),
        ],
      ),
    );
  }

  Widget _galleryPreviewTile({required String imageUrl, required int index}) {
    return SizedBox(
      width: 86,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                border: Border.all(color: AppColors.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      color: AppColors.secondary,
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tr(
              widget.language,
              ru: 'ФОТО ${index + 1}',
              en: 'PHOTO ${index + 1}',
              kk: 'ФОТО ${index + 1}',
            ),
            style: AppTypography.code.copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }
}
