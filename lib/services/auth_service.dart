import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential?> signUpWithEmail({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email, password: password,
      );
      await cred.user?.updateDisplayName(username);
      await _createUserDoc(cred.user!, username);
      return cred;
    } catch (e) { rethrow; }
  }

  Future<UserCredential?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email, password: password,
      );
    } catch (e) { rethrow; }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final cred = await _auth.signInWithCredential(credential);
      final doc = await _db.collection('users').doc(cred.user!.uid).get();
      if (!doc.exists) {
        await _createUserDoc(cred.user!,
          googleUser.displayName ?? googleUser.email.split('@')[0]);
      }
      return cred;
    } catch (e) { rethrow; }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

 Future<void> _createUserDoc(User user, String username) async {
  await _db.collection('users').doc(user.uid).set({
    'uid': user.uid,
    'name': username,          // FIX: was 'username', all screens read 'name'
    'email': user.email,
    'avatar': '🧑‍💻',
    'avatarUrl': '',
    'bio': '',
    'xp': 0,
    'weeklyXp': 0,
    'streak': 0,
    'longestStreak': 0,
    'totalMinutes': 0,
    'totalSessions': 0,
    'lastStudyDate': null,
    'subjects': [],
    'badges': [],
    'dailyGoalMinutes': 180,
    'pomodoroMode': 'classic',
    'onboardingDone': false,   // FIX: so Google sign-in routes to onboarding
    'createdAt': FieldValue.serverTimestamp(),
  });
}
}