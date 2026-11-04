import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ExternalCamerasSetupDialog extends StatefulWidget {
  const ExternalCamerasSetupDialog({Key? key}) : super(key: key);

  @override
  State<ExternalCamerasSetupDialog> createState() => _ExternalCamerasSetupDialogState();
}

class _ExternalCamerasSetupDialogState extends State<ExternalCamerasSetupDialog> {
  // 5 IP Cameras
  List<TextEditingController> ipCamCtrls = List.generate(5, (i) => TextEditingController());
  // 5 USB Cameras
  List<TextEditingController> usbCamCtrls = List.generate(5, (i) => TextEditingController());
  // 2 Drones
  List<TextEditingController> droneCtrls = List.generate(2, (i) => TextEditingController());

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      for (int i = 0; i < 5; i++) {
        ipCamCtrls[i].text = prefs.getString('ipCam_$i') ?? (i == 0 ? "http://192.168.1.100:8080/video" : "");
        usbCamCtrls[i].text = prefs.getString('usbCam_$i') ?? (i == 0 ? "/dev/video0" : "");
      }
      for (int i = 0; i < 2; i++) {
        droneCtrls[i].text = prefs.getString('drone_$i') ?? (i == 0 ? "rtsp://192.168.1.1:554/live" : "");
      }
    });
  }

  Future<void> _saveAllData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    for (int i = 0; i < 5; i++) {
      await prefs.setString('ipCam_$i', ipCamCtrls[i].text.trim());
      await prefs.setString('usbCam_$i', usbCamCtrls[i].text.trim());
    }
    for (int i = 0; i < 2; i++) {
      await prefs.setString('drone_$i', droneCtrls[i].text.trim());
    }
    if(mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("కెమెరా లింక్స్ అన్నీ సేవ్ అయ్యాయి!"), backgroundColor: Colors.green)
      );
    }
  }

  @override
  void dispose() {
    for (var c in ipCamCtrls) { c.dispose(); }
    for (var c in usbCamCtrls) { c.dispose(); }
    for (var c in droneCtrls) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: DefaultTabController(
        length: 3,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              const Text("External Cameras Setup", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const TabBar(
                indicatorColor: Colors.amber,
                labelColor: Colors.amber,
                unselectedLabelColor: Colors.white54,
                tabs: [
                  Tab(icon: Icon(Icons.wifi_tethering), text: "IP Cams (5)"),
                  Tab(icon: Icon(Icons.usb), text: "USB Cams (5)"),
                  Tab(icon: Icon(Icons.flight), text: "Drones (2)"),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildCamList("IP Camera", ipCamCtrls, "http://... or rtsp://..."),
                    _buildCamList("USB Camera", usbCamCtrls, "/dev/videoX or USB Path"),
                    _buildCamList("Drone Cam", droneCtrls, "rtsp://..."),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context), 
                    child: const Text("Close", style: TextStyle(color: Colors.redAccent))
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    onPressed: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      _saveAllData();
                    }, 
                    icon: const Icon(Icons.save, color: Colors.white), 
                    label: const Text("Save All Links", style: TextStyle(color: Colors.white))
                  )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCamList(String title, List<TextEditingController> controllers, String hint) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 15),
      itemCount: controllers.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("$title ${index + 1}", style: const TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              TextField(
                controller: controllers[index],
                style: const TextStyle(color: Colors.yellow, fontSize: 13),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
