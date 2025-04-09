import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List nodes = [];
  bool isLoading = false;
  bool isConnecting = false;

  @override
  void initState() {
    super.initState();
    fetchNodes();
  }

  void fetchNodes() async {
    setState(() => isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final response = await Dio().get(
        'https://qingshiyun.qingshihuyou.uk/api/v1/subscription/nodes',
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );
      setState(() {
        nodes = response.data['data'];
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('获取节点失败：${e.toString()}')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  void connectToNode(node) async {
    setState(() => isConnecting = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      // 生成 sing-box 配置文件
      final configContent = generateSingBoxConfig(node);
      final configFile = File('/path/to/sing-box-config.json');
      await configFile.writeAsString(configContent);

      // 启动 sing-box
      final result = await Process.run(
        'sing-box',
        ['-c', '/path/to/sing-box-config.json'],
      );

      if (result.exitCode == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('成功连接节点：${node['name']}')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('连接失败：${result.stderr}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('连接节点失败：${e.toString()}')),
      );
    } finally {
      setState(() => isConnecting = false);
    }
  }

  String generateSingBoxConfig(node) {
    // 根据节点信息生成 sing-box 配置文件内容
    return '''
{
  "inbounds": [
    {
      "port": 1080,
      "listen": "0.0.0.0",
      "protocol": "socks",
      "settings": {
        "auth": "noauth",
        "udp": false
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "vmess",
      "settings": {
        "vnext": [
          {
            "address": "${node['address']}",
            "port": ${node['port']},
            "users": [
              {
                "id": "${node['uuid']}",
                "alterId": ${node['alterId']},
                "security": "auto"
              }
            ]
          }
        ]
      }
    }
  ]
}
''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('QSY Client')),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: nodes.length,
              itemBuilder: (context, index) {
                final node = nodes[index];
                return ListTile(
                  title: Text(node['name']),
                  subtitle: Text('流量：${node['traffic'] ?? 'N/A'}'),
                  onTap: () => connectToNode(node),
                );
              },
            ),
    );
  }
}
