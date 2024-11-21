import 'package:flutter/material.dart';
import 'package:rtc_service_poc/app_wigets/svg_view.dart';
import 'package:rtc_service_poc/rtc/screens/video_call_screen.dart';

class PanelScreen extends StatelessWidget {
  const PanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Center(
                child: AssetSvgImage(
                  fileName: "panel_background",
                  folderName: "illustrations",
                  width: 150,
                  height: 150,
                ),
              ),
            ),
            SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  backgroundColor: Colors.blue,
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => VideoCallScreen(actionType: "Create"),
                    ),
                  );
                },
                icon: AssetSvgImage(
                  fileName: "video_call",
                  folderName: "icons",
                  width: 24,
                  height: 24,
                  iconColor: Colors.white,
                ),
                label: Text(
                  "Start Video Call",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
            SizedBox(height: 16),
            TextField(

              decoration: InputDecoration(
                hintText: "Enter Room ID",
                hintStyle: TextStyle(color: Colors.grey),
                prefixIcon: Icon(Icons.keyboard, color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.blue),
                ),
              ),
            ),
            SizedBox(height: 56),
          ],
        ),
      ),
    );
  }
}
