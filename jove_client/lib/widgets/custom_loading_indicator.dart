import 'package:flutter/material.dart';

class CustomLoadingIndicator extends StatelessWidget {
  const CustomLoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Image.asset(
        'assets/images/loading.gif',
        width: 60,
        height: 60,
        // Decode at display size (the source GIF is already downscaled) and
        // avoid re-decoding frames while it is on screen.
        cacheWidth: 180,
        gaplessPlayback: true,
        // Optional: you can adjust fit or color here if needed
      ),
    );
  }
}
