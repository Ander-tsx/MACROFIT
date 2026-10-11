import '../../../../core/errors/api_exception.dart';
import '../../../../core/presentation/view_model.dart';
import '../../domain/entities/privacy_notice.dart';
import '../../domain/repositories/legal_repository.dart';

class PrivacyNoticeViewModel extends ViewModel {
  PrivacyNoticeViewModel(this._repository);

  final LegalRepository _repository;

  PrivacyNotice? _notice;
  String? _error;
  bool _isLoading = false;

  PrivacyNotice? get notice => _notice;
  String? get error => _error;
  bool get isLoading => _isLoading;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _notice = await _repository.getPrivacyNotice();
    } on ApiException catch (error) {
      _error = error.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
