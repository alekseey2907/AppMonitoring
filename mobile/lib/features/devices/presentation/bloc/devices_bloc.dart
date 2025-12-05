import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

// Events
abstract class DevicesEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class DevicesLoadRequested extends DevicesEvent {}
class DeviceRefreshRequested extends DevicesEvent {}

// States
abstract class DevicesState extends Equatable {
  @override
  List<Object?> get props => [];
}

class DevicesInitial extends DevicesState {}
class DevicesLoading extends DevicesState {}
class DevicesLoaded extends DevicesState {
  final List<dynamic> devices;
  DevicesLoaded({required this.devices});
  @override
  List<Object?> get props => [devices];
}
class DevicesError extends DevicesState {
  final String message;
  DevicesError({required this.message});
  @override
  List<Object?> get props => [message];
}

// Bloc
class DevicesBloc extends Bloc<DevicesEvent, DevicesState> {
  DevicesBloc() : super(DevicesInitial()) {
    on<DevicesLoadRequested>(_onLoadRequested);
    on<DeviceRefreshRequested>(_onRefreshRequested);
  }

  Future<void> _onLoadRequested(DevicesLoadRequested event, Emitter<DevicesState> emit) async {
    emit(DevicesLoading());
    try {
      // TODO: Load devices from API
      await Future.delayed(const Duration(seconds: 1));
      emit(DevicesLoaded(devices: []));
    } catch (e) {
      emit(DevicesError(message: e.toString()));
    }
  }

  Future<void> _onRefreshRequested(DeviceRefreshRequested event, Emitter<DevicesState> emit) async {
    add(DevicesLoadRequested());
  }
}
