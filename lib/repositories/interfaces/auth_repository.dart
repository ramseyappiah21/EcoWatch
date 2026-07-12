import '../../core/errors/result.dart';
import '../../models/user.dart';

abstract class AuthRepository {
  Future<Result<User>> signIn({
    required String email,
    required String password,
  });

  Future<Result<User>> signInAnonymously();

  Future<Result<void>> signOut();

  Future<Result<User?>> getCurrentUser();

  Stream<User?> watchAuthState();
}

abstract class UserRepository {
  Future<Result<User>> updateProfile(User user);

  Future<Result<User>> updatePreferences(UserPreferences preferences);
}
