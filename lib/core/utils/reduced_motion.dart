import 'package:flutter/material.dart';

bool shouldReduceMotion(BuildContext context) {
  return MediaQuery.of(context).disableAnimations;
}

Duration animDuration(BuildContext context, Duration normal) {
  return shouldReduceMotion(context) ? Duration.zero : normal;
}
