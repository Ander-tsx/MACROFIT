import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/core/errors/api_exception.dart';
import 'package:macrofit_app/features/meals/presentation/meal_estimate/meal_estimate_view_model.dart';

import '../../../helpers/fakes.dart';

void main() {
  late FakeMealsRepository repository;
  late MealEstimateViewModel viewModel;

  setUp(() {
    repository = FakeMealsRepository();
    viewModel = MealEstimateViewModel(
      repository: repository,
      upload: testPhotoUpload,
    );
  });

  test(
    'muestra la carga mientras estima y después los alimentos y totales',
    () async {
      repository.estimateGate = Completer<void>();

      final pending = viewModel.load();
      expect(viewModel.isLoading, isTrue);
      expect(viewModel.estimate, isNull);

      repository.estimateGate!.complete();
      await pending;

      expect(repository.estimates, [testUploadedPhoto.id]);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.estimate, testEstimate);
      expect(viewModel.error, isNull);
      expect(viewModel.failure, isNull);
    },
  );

  test('con la estimación lista no vuelve a pedirla', () async {
    await viewModel.load();
    await viewModel.load();

    expect(repository.estimates, hasLength(1));
  });

  test('422 FOOD_NOT_RECOGNIZED ofrece solo la captura manual', () async {
    repository.estimateError = apiError(
      ApiErrorCode.foodNotRecognized,
      status: 422,
    );

    await viewModel.load();

    expect(viewModel.failure, EstimateFailure.notRecognized);
    expect(viewModel.error, MealEstimateViewModel.notRecognizedMessage);
    expect(viewModel.canRetry, isFalse);
    expect(viewModel.estimate, isNull);
  });

  for (final (code, status, message) in [
    (
      ApiErrorCode.foodProviderError,
      502,
      MealEstimateViewModel.providerErrorMessage,
    ),
    (
      ApiErrorCode.foodProviderTimeout,
      504,
      MealEstimateViewModel.providerTimeoutMessage,
    ),
  ]) {
    test('$status $code ofrece reintentar o capturar a mano', () async {
      repository.estimateError = apiError(code, status: status);

      await viewModel.load();

      expect(viewModel.failure, EstimateFailure.retryable);
      expect(viewModel.error, message);
      expect(viewModel.canRetry, isTrue);
      expect(viewModel.isLoading, isFalse);
    });
  }

  test('sin conexión ofrece reintentar y el reintento estima', () async {
    repository.estimateError = networkError;

    await viewModel.load();
    expect(viewModel.failure, EstimateFailure.retryable);
    expect(viewModel.error, networkError.message);

    repository.estimateError = null;
    await viewModel.retry();

    expect(repository.estimates, [testUploadedPhoto.id, testUploadedPhoto.id]);
    expect(viewModel.estimate, testEstimate);
    expect(viewModel.failure, isNull);
    expect(viewModel.error, isNull);
  });

  test(
    'otro error muestra el mensaje del servidor y permite reintentar',
    () async {
      repository.estimateError = apiError(
        ApiErrorCode.photoNotFound,
        status: 404,
        message: 'No encontramos la foto.',
      );

      await viewModel.load();

      expect(viewModel.error, 'No encontramos la foto.');
      expect(viewModel.canRetry, isTrue);
    },
  );
}
