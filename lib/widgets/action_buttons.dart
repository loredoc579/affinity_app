import 'package:flutter/material.dart';

class ActionButtons extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          CircleAvatar(child: Icon(Icons.clear), backgroundColor: Colors.purple[100]),
          CircleAvatar(child: Icon(Icons.star), backgroundColor: Colors.black),
          CircleAvatar(child: Icon(Icons.favorite), backgroundColor: Colors.blue),
        ],
      ),
    );
  }
}