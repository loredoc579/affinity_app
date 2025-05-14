import 'package:flutter/material.dart';

/// Bottom sheet interattivo per i filtri
class FilterSheet extends StatefulWidget {
  final RangeValues ageRange;
  final double maxDistance;
  final String genderFilter;
  final ValueChanged<RangeValues> onAgeChanged;
  final ValueChanged<double> onDistanceChanged;
  final ValueChanged<String> onGenderChanged;
  final VoidCallback onApply;

  const FilterSheet({
    required this.ageRange,
    required this.maxDistance,
    required this.genderFilter,
    required this.onAgeChanged,
    required this.onDistanceChanged,
    required this.onGenderChanged,
    required this.onApply,
  });

  @override
  _FilterSheetState createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late RangeValues _localAge;
  late double _localDistance;
  late String _localGender;

  @override
  void initState() {
    super.initState();
    _localAge = widget.ageRange;
    _localDistance = widget.maxDistance;
    _localGender = widget.genderFilter;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Filtri', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          // Range Età
          Text('Età: ${_localAge.start.round()} - ${_localAge.end.round()}'),
          RangeSlider(
            values: _localAge,
            min: 18,
            max: 100,
            divisions: 82,
            onChanged: (r) => setState(() {
              _localAge = r;
              widget.onAgeChanged(r);
            }),
          ),
          const SizedBox(height: 12),

          // Slider distanza
          Text('Distanza: ${_localDistance.round()} km'),
          Slider(
            value: _localDistance,
            min: 1,
            max: 800,
            divisions: 799,
            onChanged: (d) => setState(() {
              _localDistance = d;
              widget.onDistanceChanged(d);
            }),
          ),
          const SizedBox(height: 12),

          // ChoiceChip genere
          const Text('Genere'),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Tutti'),
                selected: _localGender == 'all',
                onSelected: (_) => setState(() {
                  _localGender = 'all';
                  widget.onGenderChanged('all');
                }),
              ),
              ChoiceChip(
                label: const Text('Uomini'),
                selected: _localGender == 'male',
                onSelected: (_) => setState(() {
                  _localGender = 'male';
                  widget.onGenderChanged('male');
                }),
              ),
              ChoiceChip(
                label: const Text('Donne'),
                selected: _localGender == 'female',
                onSelected: (_) => setState(() {
                  _localGender = 'female';
                  widget.onGenderChanged('female');
                }),
              ),
            ],
          ),
          const SizedBox(height: 16),

          ElevatedButton(
            onPressed: widget.onApply,
            child: const Text('Applica Filtri'),
          ),
        ],
      ),
    );
  }
}
