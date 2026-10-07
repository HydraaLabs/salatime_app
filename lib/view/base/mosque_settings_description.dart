import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:salatime/controller/quran_settings_controller.dart';
import 'package:salatime/data/model/response/mosque_settings_model.dart';
import 'package:salatime/util/dimensions.dart';
import 'package:salatime/util/styles.dart';

/// Descriptions are optional server content, and may arrive after navigation.
class MosqueSettingsDescription extends StatefulWidget {
  final String? Function(Data data) description;

  const MosqueSettingsDescription({super.key, required this.description});

  @override
  State<MosqueSettingsDescription> createState() =>
      _MosqueSettingsDescriptionState();
}

class _MosqueSettingsDescriptionState extends State<MosqueSettingsDescription> {
  late final SettingsController _settings;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _settings = Get.find<SettingsController>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await _settings.fetchMosqueSettingsData();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final data = _settings.mosqueSettingsApiData?.data;
    final description = data == null ? null : widget.description(data);
    if (description == null || description.trim().isEmpty) {
      if (_loading) {
        return const Center(child: CircularProgressIndicator());
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Dimensions.PADDING_SIZE_DEFAULT),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                (_settings.mosqueSettingsLoadFailed
                        ? 'please_try_again'
                        : 'no_data_found')
                    .tr,
              ),
              TextButton(onPressed: _load, child: Text('try_again'.tr)),
            ],
          ),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Dimensions.PADDING_SIZE_DEFAULT),
      child: Text(
        description,
        textAlign: TextAlign.justify,
        style: robotoMedium.copyWith(),
      ),
    );
  }
}
