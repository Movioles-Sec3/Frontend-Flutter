import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data' show Uint8List;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:get_it/get_it.dart';
import 'package:image_picker/image_picker.dart';
import '../di/injector.dart';
import '../services/session_manager.dart';
import '../services/profile_local_storage.dart';
import '../services/profile_photo_service.dart';
import '../core/result.dart';
import '../domain/entities/user.dart';
import '../domain/usecases/get_me_usecase.dart';
import '../domain/usecases/recharge_usecase.dart';
import '../domain/usecases/submit_seat_delivery_survey_usecase.dart';
import 'login_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _loading = true;
  String? _error;
  UserEntity? _user;
  String? _seatDeliveryInterest;
  double _prepImpactMinutes = 5;
  final TextEditingController _seatDeliveryFeedbackCtrl = TextEditingController();
  bool _surveySubmitted = false;
  bool _surveySubmitting = false;
  final ImagePicker _imagePicker = ImagePicker();
  late final ProfilePhotoService _photoService;
  late final ProfileLocalStorage _profileLocalStorage;
  Uint8List? _profilePhotoBytes;
  bool _isOffline = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _photoService = ProfilePhotoService.instance;
    _profileLocalStorage = injector.get<ProfileLocalStorage>();
    _profilePhotoBytes = _photoService.photoBytes;
    _photoService.addListener(_handlePhotoChange);
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      _handleConnectivityChange(results);
    });
    Connectivity().checkConnectivity().then((List<ConnectivityResult> results) {
      if (!mounted) return;
      _handleConnectivityChange(results, showFeedback: false);
    });
    _load();
  }

  void _handlePhotoChange() {
    if (!mounted) return;
    setState(() {
      _profilePhotoBytes = _photoService.photoBytes;
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final GetMeUseCase useCase = GetIt.I.get<GetMeUseCase>();
    final Result<UserEntity> result = await useCase();

    if (!mounted) return;

    if (result.isSuccess) {
      final UserEntity user = result.data!;
      await _profileLocalStorage.saveUser(user);
      if (!mounted) return;
      setState(() {
        _user = user;
        _loading = false;
        _isOffline = false;
        _error = null;
      });
    } else {
      final List<ConnectivityResult> connectivityResults =
          await Connectivity().checkConnectivity();
      _handleConnectivityChange(connectivityResults, showFeedback: false);
      final bool offline = _isOfflineFromResults(connectivityResults);
      final UserEntity? cached = await _profileLocalStorage.getUser();
      if (!mounted) return;
      if (cached != null) {
        setState(() {
          _user = cached;
          _loading = false;
          _error = offline ? null : (result.error ?? 'Unable to load profile');
          _isOffline = offline;
        });
        if (offline) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text(
                  'No internet connection. Showing saved profile.',
                ),
              ),
            );
        }
      } else {
        setState(() {
          _error = offline
              ? 'No internet connection.'
              : (result.error ?? 'Unable to load profile');
          _loading = false;
          _isOffline = offline;
        });
        if (offline) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text('No internet connection. Try again later.'),
              ),
            );
        }
      }
    }
  }

  Future<void> _captureProfilePhoto() async {
    if (_isOffline) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Cannot use the camera while offline.'),
          ),
        );
      return;
    }
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 85,
        maxWidth: 720,
        maxHeight: 720,
      );
      if (photo == null) return;

      final Uint8List bytes = photo.path.isNotEmpty
          ? await _loadPhotoBytesIsolate(photo.path)
          : await photo.readAsBytes();
      _photoService.update(bytes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated')),
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to open the camera: ${e.message ?? e.code}')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not capture photo')),
      );
    }
  }

  Future<Uint8List> _loadPhotoBytesIsolate(String path) {
    return Isolate.run(() => File(path).readAsBytesSync());
  }

  void _handleConnectivityChange(List<ConnectivityResult> results,
      {bool showFeedback = true}) {
    if (!mounted) return;
    final bool offline = _isOfflineFromResults(results);
    if (offline != _isOffline) {
      setState(() {
        _isOffline = offline;
      });
      if (showFeedback) {
        final ScaffoldMessengerState messenger =
            ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              offline
                  ? 'No internet connection. Some actions are disabled.'
                  : 'Back online. You can use all actions again.',
            ),
          ),
        );
      }
    } else if (showFeedback && offline) {
      final ScaffoldMessengerState messenger =
          ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No internet connection. Some actions are disabled.'),
        ),
      );
    }
  }

  bool _isOfflineFromResults(List<ConnectivityResult> results) {
    if (results.isEmpty) return true;
    return results.every((ConnectivityResult result) => result == ConnectivityResult.none);
  }

  @override
  void dispose() {
    _photoService.removeListener(_handlePhotoChange);
    _seatDeliveryFeedbackCtrl.dispose();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _logout() async {
    await SessionManager.clear();
    await _profileLocalStorage.clear();
    _photoService.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginPage()),
      (Route<dynamic> _) => false,
    );
  }

  Future<void> _showRechargeDialog() async {
    final TextEditingController amountCtrl = TextEditingController();
    final double? amount = await showDialog<double>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add funds'),
          content: TextField(
            controller: amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(hintText: 'Amount'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final String raw = amountCtrl.text.trim().replaceAll(',', '.');
                final double? parsed = double.tryParse(raw);
                if (parsed == null || parsed <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter a valid amount')),
                  );
                  return;
                }
                Navigator.of(context).pop(parsed);
              },
              child: const Text('Add funds'),
            ),
          ],
        );
      },
    );

    if (amount != null) {
      await _recharge(amount);
    }
  }

  Future<void> _recharge(double amount) async {
    final RechargeUseCase useCase = GetIt.I.get<RechargeUseCase>();
    final Result<UserEntity> result = await useCase(amount);

    if (!mounted) return;

    if (result.isSuccess) {
      final UserEntity updatedUser = result.data!;
      await _profileLocalStorage.saveUser(updatedUser);
      if (!mounted) return;
      setState(() {
        _user = updatedUser;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Funds added')));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.error!)));
    }
  }

  String _mapInterestToApi(String interest) {
    switch (interest) {
      case 'high':
        return 'HIGH';
      case 'medium':
        return 'MODERATE';
      case 'low':
      default:
        return 'LOW';
    }
  }

  String _interestLabel(String interest) {
    switch (interest) {
      case 'high':
        return 'High interest';
      case 'medium':
        return 'Moderate interest';
      case 'low':
      default:
        return 'Low interest';
    }
  }

  Future<void> _submitSeatDeliverySurvey() async {
    if (_seatDeliveryInterest == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick your level of interest before submitting.')),
      );
      return;
    }
    if (_surveySubmitting) return;

    setState(() {
      _surveySubmitting = true;
    });

    final SubmitSeatDeliverySurveyUseCase useCase =
        GetIt.I.get<SubmitSeatDeliverySurveyUseCase>();
    final String feedback = _seatDeliveryFeedbackCtrl.text.trim();
    final Result<void> result = await useCase(
      interestLevel: _mapInterestToApi(_seatDeliveryInterest!),
      extraMinutes: _prepImpactMinutes.round(),
      comments: feedback.isEmpty ? null : feedback,
    );

    if (!mounted) return;

    setState(() {
      _surveySubmitting = false;
      if (result.isSuccess) {
        _surveySubmitted = true;
      }
    });

    if (result.isSuccess) {
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Thanks! ${_interestLabel(_seatDeliveryInterest!)} · Estimated impact: ${_prepImpactMinutes.toStringAsFixed(0)} min.${feedback.isEmpty ? '' : ' Feedback: $feedback'}',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Unable to submit survey')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (_isOffline)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orangeAccent),
                ),
                child: const Text(
                  'No internet connection. Please reconnect and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.orangeAccent),
                ),
              ),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final UserEntity user =
        _user ?? UserEntity(id: 0, name: '', email: '', balance: 0);
    final String nombre = user.name;
    final String email = user.email;
    final String id = user.id.toString();
    final String saldo = user.balance.toString();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (_isOffline)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orangeAccent),
                ),
                child: const Text(
                  'No internet connection. You are seeing saved information.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.orangeAccent),
                ),
              ),
            Center(
              child: _ProfileAvatar(
                displayName: nombre,
                photoBytes: _profilePhotoBytes,
                onCaptureTap: _isOffline ? null : _captureProfilePhoto,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                nombre.isEmpty ? 'User' : nombre,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Column(
                children: <Widget>[
                  ListTile(
                    leading: const Icon(Icons.badge_outlined),
                    title: const Text('ID'),
                    subtitle: Text(id),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.email_outlined),
                    title: const Text('Email'),
                    subtitle: Text(email),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.account_balance_wallet_outlined),
                    title: const Text('Balance'),
                    subtitle: Text(saldo),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _SeatDeliverySurveyCard(
              interestValue: _seatDeliveryInterest,
              onInterestChanged: (String? v) {
                setState(() {
                  _seatDeliveryInterest = v;
                });
              },
              prepImpactMinutes: _prepImpactMinutes,
              onImpactChanged: (double v) {
                setState(() {
                  _prepImpactMinutes = v;
                });
              },
              feedbackController: _seatDeliveryFeedbackCtrl,
              onSubmit: _submitSeatDeliverySurvey,
              submitted: _surveySubmitted,
              submitting: _surveySubmitting,
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isOffline ? null : _showRechargeDialog,
                icon: const Icon(Icons.account_balance_wallet_outlined),
                label: const Text('Add funds'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: _logout,
                icon: const Icon(Icons.logout),
                label: const Text('Log out'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.displayName,
    required this.photoBytes,
    this.onCaptureTap,
  });

  final String displayName;
  final Uint8List? photoBytes;
  final VoidCallback? onCaptureTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ImageProvider<Object>? imageProvider =
        photoBytes == null ? null : MemoryImage(photoBytes!);
    final bool isEnabled = onCaptureTap != null;

    return SizedBox(
      width: 112,
      height: 112,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned.fill(
            child: CircleAvatar(
              radius: 56,
              backgroundImage: imageProvider,
              child: imageProvider != null
                  ? null
                  : Text(
                      displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Material(
              color: isEnabled
                  ? theme.colorScheme.primary
                  : theme.disabledColor,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onCaptureTap,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    Icons.camera_alt_outlined,
                    size: 18,
                    color: isEnabled
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SeatDeliverySurveyCard extends StatelessWidget {
  const _SeatDeliverySurveyCard({
    required this.interestValue,
    required this.onInterestChanged,
    required this.prepImpactMinutes,
    required this.onImpactChanged,
    required this.feedbackController,
    required this.onSubmit,
    required this.submitted,
    required this.submitting,
  });

  final String? interestValue;
  final ValueChanged<String?> onInterestChanged;
  final double prepImpactMinutes;
  final ValueChanged<double> onImpactChanged;
  final TextEditingController feedbackController;
  final VoidCallback onSubmit;
  final bool submitted;
  final bool submitting;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<_InterestOption> options = <_InterestOption>[
      const _InterestOption(value: 'high', label: 'High interest', description: 'I would look for it often and place seat-delivery orders.'),
      const _InterestOption(value: 'medium', label: 'Moderate interest', description: 'I would try it or recommend it in some situations.'),
      const _InterestOption(value: 'low', label: 'Low interest', description: 'I probably would not use a seat-delivery option.'),
    ];

    final Widget submitIcon = submitting
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.poll_outlined);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Survey: Seat Delivery Feature',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'We are gauging interest in delivering orders directly to your seat. Tell us how valuable it would be and how it might affect prep/serving times.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Text(
              'How interested are you in seat delivery?',
              style: theme.textTheme.titleSmall,
            ),
            for (final _InterestOption option in options)
              RadioListTile<String>(
                title: Text(option.label),
                subtitle: Text(option.description),
                value: option.value,
                groupValue: interestValue,
                onChanged: submitted || submitting ? null : onInterestChanged,
              ),
            const SizedBox(height: 16),
            Text(
              'How many extra minutes do you think it would add to prep/serving?',
              style: theme.textTheme.titleSmall,
            ),
            Slider(
              value: prepImpactMinutes,
              min: 0,
              max: 20,
              divisions: 20,
              label: '${prepImpactMinutes.toStringAsFixed(0)} min',
              onChanged: submitted || submitting ? null : onImpactChanged,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${prepImpactMinutes.toStringAsFixed(0)} additional minutes',
                style: theme.textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Comments (optional)',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: feedbackController,
              enabled: !(submitted || submitting),
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Tell us how it should work or any concerns you have.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                FilledButton.icon(
                  onPressed: submitted || submitting ? null : onSubmit,
                  icon: submitIcon,
                  label: Text(submitting ? 'Submitting...' : 'Submit response'),
                ),
                if (submitted) ...<Widget>[
                  const SizedBox(width: 12),
                  Chip(
                    avatar: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Response recorded'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InterestOption {
  const _InterestOption({required this.value, required this.label, required this.description});

  final String value;
  final String label;
  final String description;
}
