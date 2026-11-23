import 'package:flutter/widgets.dart';

const _ink = Color(0xFF302449);
const _policyText = '''
Effective November 23, 2026

Flutris is a falling-block puzzle game published by Khondakar Afridi (WorkWithAfridi).

INFORMATION FLUTRIS HANDLES

Flutris does not collect or transmit personal information, device identifiers, or gameplay data. The app has no account sign-in, advertising, analytics, or online score service.

The app saves each game mode's best score in local app preferences on your device so the score is available the next time you play. These scores are not sent to the developer or to third parties. Local scores are removed when you uninstall Flutris or clear its app data.

Sound effects, music, and haptic feedback are generated or played on your device. Flutris does not access your contacts, location, camera, microphone, photos, or files.

THIRD-PARTY SERVICES

Flutris does not include advertising, analytics, or tracking services. The app uses Flutter and Flame game framework libraries to render and run the game, flame_audio for local bundled sounds, and shared_preferences for on-device score storage.

CHILDREN'S PRIVACY

Flutris does not knowingly collect personal information from children or any other users. Because the app does not collect or transmit personal information, there is no account or remote profile to delete.

CHANGES AND CONTACT

If the app's data practices change, this policy will be updated before or when those changes take effect. For privacy questions, contact Khondakar Afridi at afridi.khondakar@gmail.com.''';

/// An in-app privacy disclosure available from the handheld shell at all times.
class PrivacyPolicyOverlay extends StatelessWidget {
  const PrivacyPolicyOverlay({required this.onClose, super.key});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xDD211B2A),
    child: SafeArea(
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 760),
          margin: const EdgeInsets.all(18),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          decoration: BoxDecoration(
            color: const Color(0xFFB5C49D),
            border: Border.all(color: const Color(0xFF171E20), width: 3),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(color: Color(0x80533E68), offset: Offset(0, 7), blurRadius: 0),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'PRIVACY POLICY',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onClose,
                    child: Semantics(
                      button: true,
                      label: 'Close privacy policy',
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Text(
                          'CLOSE  ×',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .6,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(height: 1, color: _ink.withValues(alpha: .25)),
              const SizedBox(height: 10),
              const Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    _policyText,
                    style: TextStyle(
                      color: _ink,
                      fontSize: 10,
                      height: 1.55,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
