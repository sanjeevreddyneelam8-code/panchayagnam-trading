import 'dart:html' as html;
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/add_demat_account_request.dart';
import '../../repo/add_demat_acc_repository.dart';
import '../../service/service_class.dart';
part 'add_demat_event.dart';
part 'add_demat_state.dart';

class AddDematBloc extends Bloc<AddDematEvent, AddDematAccountState> {
  final AddDematAccountRepository _repository;

  AddDematBloc({AddDematAccountRepository? repository})
    : _repository = repository ?? AngelOneRepositoryImpl(),
      super(AddDematAccountInitial()) {
    on<AddDematAccountEvent>(_onAddDematAccount);
    on<ResetAddDematEvent>(_onReset);
  }

  Future<void> _onAddDematAccount(
    AddDematAccountEvent event,
    Emitter<AddDematAccountState> emit,
  ) async {
    emit(AddDematAccountLoading());
    try {
      final int pyId = int.parse(html.window.sessionStorage['user_id'] ?? '0');

      final bool isMotilal = event.broker.toUpperCase().contains('MOTILAL');

      final request = AddDematAccountRequest(
        id: event.id,
        clientId: event.clientId,
        apiKey: event.apiKey,
        mpin: event.mpin,
        password: event.password,
        totpReferenceKey: event.totpReferenceKey,
        brokerType: event.broker,
        isAdmin: event.isAdmin,
        childIds: event.childIds,
        nickName: event.nickName,
        isActive: event.active ?? true,
        pyUserId: pyId,
        dob: event.dob,
        // Broker API secret key
        apiSecretKey: event.apiSecretKey,
        vendorInfo: isMotilal
            ? (event.vendorInfo?.isNotEmpty == true
                  ? event.vendorInfo
                  : event.clientId)
            : event.vendorInfo,
        isOwn: event.isOwn,
        ip: event.ip ?? "",
        mobileNumber: event.mobileNumber ?? "",
      );

      final response = await _repository.addAngelOneAccount(
        request,
        event.actionType,
      );

      emit(
        AddDematAccountSuccess(
          message: response.message ?? 'Account added successfully!',
        ),
      );
    } on ServiceException catch (e) {
      emit(AddDematAccountFailure(error: e.message));
    } catch (e) {
      emit(
        AddDematAccountFailure(
          error: 'Something went wrong. Please try again.',
        ),
      );
    }
  }

  void _onReset(ResetAddDematEvent event, Emitter<AddDematAccountState> emit) {
    emit(AddDematAccountInitial());
  }
}
