import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class RegisterRequested extends AuthEvent {
  final String fullName;
  final String email;
  final String phoneNumber;
  final String mpin;
  final String otp;

  const RegisterRequested({
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.mpin,
    required this.otp,
  });

  @override
  List<Object?> get props => [fullName, email, phoneNumber, mpin, otp];
}

class LoginRequested extends AuthEvent {
  final String phoneNumber;
  final String mpin;

  const LoginRequested({required this.phoneNumber, required this.mpin});

  @override
  List<Object?> get props => [phoneNumber, mpin];
}

class LoginWithOtpRequested extends AuthEvent {
  final String phoneNumber;
  final String otp;

  const LoginWithOtpRequested({required this.phoneNumber, required this.otp});

  @override
  List<Object?> get props => [phoneNumber, otp];
}

class ForgotMpinRequested extends AuthEvent {
  final String phoneNumber;

  const ForgotMpinRequested({required this.phoneNumber});

  @override
  List<Object?> get props => [phoneNumber];
}

class ResetMpinRequested extends AuthEvent {
  final String phoneNumber;
  final String otp;
  final String newMpin;

  const ResetMpinRequested({
    required this.phoneNumber,
    required this.otp,
    required this.newMpin,
  });

  @override
  List<Object?> get props => [phoneNumber, otp, newMpin];
}

class SendOtpRequested extends AuthEvent {
  final String phoneNumber;
  final String codeReqFor;

  const SendOtpRequested({required this.phoneNumber, required this.codeReqFor});

  @override
  List<Object?> get props => [phoneNumber];
}

class AuthReset extends AuthEvent {}

class LogoutRequested extends AuthEvent {}
