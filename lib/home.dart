import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:ui';

import 'package:bluetooth_enable_fork/bluetooth_enable_fork.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
//import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
//import 'package:flutter_blue/flutter_blue.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:project_ecg/data_model.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:http/http.dart' as http;

class Home extends StatefulWidget {
  const Home({Key? key}) : super(key: key);

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {

  //FlutterBlue flutterBlue = FlutterBlue.instance;
  //FlutterBluePlus flutterBlue = FlutterBluePlus.instance;
  List<BluetoothDevice> deviceList=<BluetoothDevice>[];
  //FlutterBluetoothSerial flutterBlue=FlutterBluetoothSerial.instance;
  List<DataModel> data=[];
  List<DataModel> heartBPM = [];
  String heartRate="00";

  void ConnectToModule() async{

    BluetoothDevice device=deviceList[deviceList.indexWhere((element)=>
    element.address.toString()=="00:20:12:08:B1:35"
    )];
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(device.name.toString()),
        ));

    try{
      //await device.connect();
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeRight,
        DeviceOrientation.landscapeLeft,
      ]);
      BluetoothConnection connection = await BluetoothConnection.toAddress(device.address);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(connection.isConnected.toString()),
          ));
      print('Connected to the device');
      int t=0;

      String inData="";

      connection.input?.listen((event)  {
        String res = String.fromCharCodes(event).replaceAll("!", "");
        print(res);
        try{
          final dataDecode = jsonDecode(res);
          setState(() {
            heartRate=dataDecode["Rate"].toString();
          });
          if(data.length<120){
            setState(() {
              data.add(DataModel(y_cordi:double.parse(dataDecode["Value"].toString()) , x_cordi: DateTime.now().millisecondsSinceEpoch));
              heartBPM.add(DataModel(y_cordi:double.parse(heartRate) , x_cordi: DateTime.now().millisecondsSinceEpoch));
            });
          }else{
            setState(() {
              data.removeAt(0);
              heartBPM.removeAt(0);
              data.add(DataModel(y_cordi:double.parse(dataDecode["Value"].toString()) , x_cordi: DateTime.now().millisecondsSinceEpoch));
              heartBPM.add(DataModel(y_cordi:double.parse(heartRate) , x_cordi: DateTime.now().millisecondsSinceEpoch));
            });
            //print(data);
          }
        }catch(e){
          print(e);
        }

      });

    }catch(e){
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
          ));
    }
  }

  void EnableBluetooth() async{
    await Permission.bluetooth.request();
    await Permission.bluetoothConnect.request();
    await Permission.bluetoothScan.request();

    BluetoothEnable.enableBluetooth.then((result) {
      if (result == "true") {
        // Bluetooth has been enabled
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Bluetooth has been enabled')),
        );

        scanDevices();

      }
      else if (result == "false") {
        // Bluetooth has not been enabled
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Bluetooth cannot be enabled')),
        );
      }
    });

  }

  void scanDevices() async{

    deviceList.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('Scanning devices please wait')),
    );

    //flutter blue serial
    StreamSubscription<BluetoothDiscoveryResult> _streamSubscription;
    _streamSubscription =
        FlutterBluetoothSerial.instance.startDiscovery().listen((r) {
          print(r.device.name);
          print(r);
          setState(() {
            deviceList.add(r.device);
          });
          if(r.device.name.toString()=="NVCTI10"){
            ConnectToModule();
          }
        });

    _streamSubscription.onDone(() {

    });


    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Stop Scan Called'),
        ));

    print('Stop Scan Called');

    //flutter blue//fluter blue plus
    // flutterBlue.stopScan().then((value){
    //   if(deviceList.length>0)
    //     ConnectToModule();
    // });

  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    EnableBluetooth();
  }

  GlobalKey<SfCartesianChartState> cartesianChartKey = GlobalKey();
  GlobalKey<SfCartesianChartState> cartesianChartKey2 = GlobalKey();

  void processImage() async{
    String bpm = heartRate;
    final image = await cartesianChartKey.currentState!.toImage();
    final bytes = await image.toByteData(format: ImageByteFormat.png);
    final Uint8List imageBytes = bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
    String base64Image = base64Encode(imageBytes);
    print(base64Image);
    String baseUrl = "https://4402-152-59-171-255.ngrok-free.app/predict";
    try{
      var request = http.MultipartRequest("POST", Uri.parse(baseUrl));
      //request.headers.addAll(heads);
      request.fields['image']=base64Image;
      var response = await request.send();
      print(response.statusCode);
      response.stream.transform(utf8.decoder).listen((value) async {

        print("Response => "+value);
        var data=jsonDecode(value);
        print("Output => "+data['class']);

        showModalBottomSheet<void>(
            context: context,
            builder: (BuildContext context) {
              return Container(
                height: 200,
                width: MediaQuery
                    .of(context)
                    .size
                    .width,
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: Column(
                    children: [
                      Image.memory(imageBytes),
                      Text("BPM = $bpm"),
                      Text(data['class'].toString())
                    ],
                  ),
                ),
              );
            });
      });
    }catch(e){
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: Column(
            children: [

              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Center(
                  child: Text("Plot of Heart Signal",style: TextStyle(fontWeight: FontWeight.bold,fontSize: 15),),
                ),
              ),

              Padding(
                padding: EdgeInsets.all(8),
                child: Container(
                  height: MediaQuery.of(context).size.height/1.5,
                  width: MediaQuery.of(context).size.width,
                  child: SfCartesianChart(
                    key: cartesianChartKey,
                    enableAxisAnimation: true,
                    primaryXAxis: NumericAxis(
                      isVisible:false,

                    ),
                    series: <ChartSeries>[
                      LineSeries<DataModel,int>
                        (dataSource: data,
                          xValueMapper: (DataModel dataModel,_)=>dataModel.x_cordi,
                          yValueMapper: (DataModel dataModel,_)=>dataModel.y_cordi
                      )
                    ],
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Center(
                  child: Text("Plot of Heart Rate",style: TextStyle(fontWeight: FontWeight.bold,fontSize: 15),),
                ),
              ),

              Padding(
                padding: EdgeInsets.all(8),
                child: Container(
                  height: MediaQuery.of(context).size.height/1.5,
                  width: MediaQuery.of(context).size.width,
                  child: SfCartesianChart(
                    key: cartesianChartKey2,
                    enableAxisAnimation: true,
                    primaryXAxis: NumericAxis(
                      isVisible:false,
                    ),
                    series: <ChartSeries>[
                      LineSeries<DataModel,int>
                        (dataSource: heartBPM,
                          xValueMapper: (DataModel dataModel,_)=>dataModel.x_cordi,
                          yValueMapper: (DataModel dataModel,_)=>dataModel.y_cordi
                      )
                    ],
                  ),
                ),
              ),

              Center(
                child:GestureDetector(
                  onTap: (){
                    if(data.length>=120){
                      processImage();
                    }else{
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Wait for the data to get collected'),
                          ));
                    }
                  },
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.all(Radius.circular(75)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Center(child: Text(heartRate,style: TextStyle(color: Colors.white,fontSize: 40,fontWeight: FontWeight.bold),)),
                        ),
                        Center(child: Text("BPM",style: TextStyle(color: Colors.white),))
                      ],
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      )
    );
  }
}
