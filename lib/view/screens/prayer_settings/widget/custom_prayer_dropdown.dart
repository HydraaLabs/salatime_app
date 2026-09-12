// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:zabi/util/dimensions.dart';
import 'package:zabi/util/styles.dart';

class CustomPrayerSettingDropDown extends StatelessWidget {
  final String? dwValue;
  final List<dynamic> dwItems;
  final Function(dynamic value) onChange;
  final double? width;
  final String? hintText;
  final Color? textColor;
  final Color? borderColor;
  final Color? bgColor;
  final String? header;
  final bool isRequired;
  final Color? itemColor;
  final TextStyle? titleTextStyle;
  final bool isFillColor;
  final bool isBorder;
  final String? Function(String?)? validator;
  final double? dropdownHeight; // Custom total dropdown height property

  const CustomPrayerSettingDropDown({
    super.key,
    required this.dwItems,
    required this.dwValue,
    required this.onChange,
    this.width,
    this.bgColor,
    this.borderColor,
    this.hintText,
    this.textColor,
    this.header,
    this.isRequired = false,
    this.itemColor,
    this.titleTextStyle,
    this.isFillColor = false,
    this.isBorder = true,
    this.validator,
    this.dropdownHeight, // Added dropdownHeight to constructor
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(Dimensions.RADIUS_SMALL),
      child: ButtonTheme(
        alignedDropdown: true,
        padding: EdgeInsets.zero,
        child: DropdownButtonFormField<String>(
          validator: validator,
          dropdownColor: Theme.of(context).cardColor,
          menuMaxHeight: dropdownHeight, // Set custom dropdown height here
          decoration: InputDecoration(
            filled: true,
            fillColor: Theme.of(context).cardColor,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 0,
              vertical: Dimensions.PADDING_SIZE_SMALL + 3,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Dimensions.RADIUS_DEFAULT),
              borderSide: BorderSide(
                color: Theme.of(context).primaryColor.withOpacity(0.5),
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Dimensions.RADIUS_DEFAULT),
              borderSide: BorderSide(
                color: Theme.of(context).primaryColor.withOpacity(0.5),
                width: 1,
              ),
            ),
          ),
          borderRadius: BorderRadius.circular(Dimensions.RADIUS_SMALL),
          hint: Text(
            hintText ?? '',
            style: robotoMedium.copyWith(overflow: TextOverflow.ellipsis),
          ),
          icon: Padding(
            padding: const EdgeInsets.only(
              right: Dimensions.PADDING_SIZE_EXTRA_SMALL,
            ),
            child: Icon(
              Icons.keyboard_arrow_down,
              color: Theme.of(context).primaryColor,
            ),
          ),
          isExpanded: true,
          isDense: true,
          itemHeight: null,
          value: dwValue,
          selectedItemBuilder: (context) => dwItems
              .map<Widget>(
                (item) => Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: Dimensions.PADDING_SIZE_DEFAULT,
                  ),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Tooltip(
                      message: item['value'],
                      child: Text(
                        item['value'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: robotoMedium.copyWith(
                          fontSize: Dimensions.FONT_SIZE_DEFAULT,
                        ),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: (newValue) {
            onChange(newValue);
          },
          items: dwItems
              .map(
                (item) => DropdownMenuItem<String>(
                  value: item['id'].toString(),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: Dimensions.PADDING_SIZE_DEFAULT,
                      top: Dimensions.PADDING_SIZE_SMALL,
                      bottom: Dimensions.PADDING_SIZE_SMALL,
                    ),
                    child: Text(
                      item['value'],
                      textAlign: TextAlign.start,
                      style: robotoMedium.copyWith(
                        fontSize: Dimensions.FONT_SIZE_DEFAULT,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
