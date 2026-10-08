import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:image_picker/image_picker.dart';

import 'firebase_options.dart';


// ============================================================
// MAIN
// ============================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const SamarraMarket());
}


// ============================================================
// APP
// ============================================================

class SamarraMarket extends StatelessWidget {
  const SamarraMarket({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      title: 'سوق سامراء',

      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
        ),
        fontFamily: 'Arial',
      ),

      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),

        builder: (context, snapshot) {

          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          if (snapshot.hasData) {
            return const HomePage();
          }

          return const LoginPage();
        },
      ),
    );
  }
}


// ============================================================
// LOGIN
// ============================================================

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {

  bool loading = false;

  Future<void> googleLogin() async {

    try {

      setState(() {
        loading = true;
      });

      final account =
          await GoogleSignIn().signIn();

      if (account == null) return;

      final auth =
          await account.authentication;

      final credential =
          GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken: auth.idToken,
      );

      final result =
          await FirebaseAuth.instance
              .signInWithCredential(
        credential,
      );

      await createUser(result.user);

    } catch (e) {

      showMessage(
        context,
        'خطأ في تسجيل الدخول: $e',
      );

    } finally {

      setState(() {
        loading = false;
      });
    }
  }


  Future<void> facebookLogin() async {

    try {

      setState(() {
        loading = true;
      });

      final result =
          await FacebookAuth.instance.login();

      if (result.status !=
          LoginStatus.success) {
        throw Exception(
          'تم إلغاء تسجيل الدخول',
        );
      }

      final credential =
          FacebookAuthProvider.credential(
        result.accessToken!.tokenString,
      );

      final user =
          await FirebaseAuth.instance
              .signInWithCredential(
        credential,
      );

      await createUser(user.user);

    } catch (e) {

      showMessage(
        context,
        'خطأ: $e',
      );

    } finally {

      setState(() {
        loading = false;
      });
    }
  }


  Future<void> createUser(User? user) async {

    if (user == null) return;

    final ref =
        FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid);

    final data =
        await ref.get();

    if (!data.exists) {

      await ref.set({

        'uid': user.uid,

        'name':
            user.displayName ?? '',

        'email':
            user.email ?? '',

        'photo':
            user.photoURL ?? '',

        'username': '',

        'createdAt':
            FieldValue.serverTimestamp(),
      });
    }
  }


  @override
  Widget build(BuildContext context) {

    return Scaffold(

      body: SafeArea(

        child: Center(

          child: Padding(

            padding:
                const EdgeInsets.all(25),

            child: Column(

              mainAxisAlignment:
                  MainAxisAlignment.center,

              children: [

                const Icon(
                  Icons.phone_android,
                  size: 100,
                ),

                const SizedBox(
                  height: 20,
                ),

                const Text(
                  'سوق سامراء',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 10,
                ),

                const Text(
                  'بيع وشراء الهواتف المستعملة',
                ),

                const SizedBox(
                  height: 40,
                ),

                SizedBox(
                  width: double.infinity,
                  height: 55,

                  child:
                      ElevatedButton.icon(

                    icon: const Icon(
                      Icons.g_mobiledata,
                      size: 30,
                    ),

                    label: const Text(
                      'تسجيل الدخول بواسطة Google',
                    ),

                    onPressed:
                        loading
                            ? null
                            : googleLogin,
                  ),
                ),

                const SizedBox(
                  height: 15,
                ),

                SizedBox(
                  width: double.infinity,
                  height: 55,

                  child:
                      ElevatedButton.icon(

                    icon:
                        const Icon(
                      Icons.facebook,
                    ),

                    label:
                        const Text(
                      'تسجيل الدخول بواسطة Facebook',
                    ),

                    onPressed:
                        loading
                            ? null
                            : facebookLogin,
                  ),
                ),

                if (loading)
                  const Padding(
                    padding:
                        EdgeInsets.all(20),
                    child:
                        CircularProgressIndicator(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


// ============================================================
// USERNAME
// ============================================================

class UsernamePage extends StatefulWidget {
  const UsernamePage({super.key});

  @override
  State<UsernamePage> createState() =>
      _UsernamePageState();
}

class _UsernamePageState
    extends State<UsernamePage> {

  final controller =
      TextEditingController();

  bool loading = false;

  Future<void> saveUsername() async {

    final username =
        controller.text
            .trim()
            .toLowerCase();

    if (username.length < 3) {

      showMessage(
        context,
        'اسم المستخدم يجب أن يكون 3 أحرف على الأقل',
      );

      return;
    }

    try {

      setState(() {
        loading = true;
      });

      final uid =
          FirebaseAuth.instance
              .currentUser!
              .uid;

      final existing =
          await FirebaseFirestore.instance
              .collection('users')
              .where(
                'username',
                isEqualTo: username,
              )
              .limit(1)
              .get();

      if (existing.docs.isNotEmpty &&
          existing.docs.first.id != uid) {

        throw Exception(
          'اسم المستخدم مستخدم مسبقاً',
        );
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({
        'username': username,
      });

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) =>
              const HomePage(),
        ),
        (_) => false,
      );

    } catch (e) {

      showMessage(
        context,
        e.toString()
            .replaceFirst(
          'Exception: ',
          '',
        ),
      );

    } finally {

      setState(() {
        loading = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title:
            const Text(
          'اسم المستخدم',
        ),
      ),

      body: Padding(

        padding:
            const EdgeInsets.all(20),

        child: Column(

          children: [

            const SizedBox(
              height: 30,
            ),

            const Text(
              'اختار اسم المستخدم الخاص بك',
              style:
                  TextStyle(
                fontSize: 22,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 25,
            ),

            TextField(

              controller:
                  controller,

              decoration:
                  const InputDecoration(
                labelText:
                    'اسم المستخدم',
                hintText:
                    'مثال: ali_samarr',
                border:
                    OutlineInputBorder(),
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            SizedBox(
              width:
                  double.infinity,
              height: 52,

              child:
                  ElevatedButton(

                onPressed:
                    loading
                        ? null
                        : saveUsername,

                child:
                    loading
                        ? const CircularProgressIndicator()
                        : const Text(
                            'حفظ',
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ============================================================
// HOME
// ============================================================

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() =>
      _HomePageState();
}

class _HomePageState
    extends State<HomePage> {

  int currentPage = 0;

  final pages = const [
    HomePostsPage(),
    ChatsListPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      body:
          pages[currentPage],

      bottomNavigationBar:
          NavigationBar(

        selectedIndex:
            currentPage,

        onDestinationSelected:
            (index) {

          setState(() {
            currentPage =
                index;
          });
        },

        destinations: const [

          NavigationDestination(
            icon:
                Icon(Icons.home_outlined),
            selectedIcon:
                Icon(Icons.home),
            label:
                'الرئيسية',
          ),

          NavigationDestination(
            icon:
                Icon(Icons.message_outlined),
            selectedIcon:
                Icon(Icons.message),
            label:
                'الرسائل',
          ),

          NavigationDestination(
            icon:
                Icon(Icons.person_outline),
            selectedIcon:
                Icon(Icons.person),
            label:
                'حسابي',
          ),
        ],
      ),

      floatingActionButton:
          currentPage == 0
              ? FloatingActionButton.extended(

                  icon:
                      const Icon(Icons.add),

                  label:
                      const Text(
                    'بيع هاتف',
                  ),

                  onPressed: () {

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const CreatePostPage(),
                      ),
                    );
                  },
                )
              : null,
    );
  }
}


// ============================================================
// POSTS
// ============================================================

class HomePostsPage
    extends StatelessWidget {

  const HomePostsPage({super.key});

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(

        title:
            const Text(
          'سوق سامراء 📱',
        ),

        actions: [

          IconButton(
            icon:
                const Icon(
              Icons.search,
            ),

            onPressed: () {

              showSearch(
                context:
                    context,
                delegate:
                    PhoneSearchDelegate(),
              );
            },
          ),
        ],
      ),

      body:

          StreamBuilder<QuerySnapshot>(

        stream:
            FirebaseFirestore
                .instance
                .collection('posts')
                .orderBy(
                  'createdAt',
                  descending: true,
                )
                .snapshots(),

        builder:
            (context, snapshot) {

          if (snapshot.hasError) {

            return Center(
              child:
                  Text(
                'حدث خطأ: ${snapshot.error}',
              ),
            );
          }

          if (!snapshot.hasData) {

            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          final posts =
              snapshot.data!.docs;

          if (posts.isEmpty) {

            return const Center(
              child:
                  Text(
                'ماكو إعلانات حالياً 😅',
              ),
            );
          }

          return ListView.builder(

            padding:
                const EdgeInsets.all(10),

            itemCount:
                posts.length,

            itemBuilder:
                (context, index) {

              final post =
                  posts[index].data()
                      as Map<String,
                          dynamic>;

              return PostCard(

                id:
                    posts[index].id,

                data:
                    post,
              );
            },
          );
        },
      ),
    );
  }
}


// ============================================================
// POST CARD
// ============================================================

class PostCard extends StatelessWidget {

  final String id;
  final Map<String, dynamic> data;

  const PostCard({
    super.key,
    required this.id,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {

    final likes =
        List.from(
      data['likes'] ?? [],
    );

    final uid =
        FirebaseAuth.instance
            .currentUser!
            .uid;

    return Card(

      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),

      clipBehavior:
          Clip.antiAlias,

      child: InkWell(

        onTap: () {

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  PostDetailsPage(
                postId: id,
                data: data,
              ),
            ),
          );
        },

        child: Column(

          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [

            if (data['imageUrl'] != null)

              Image.network(

                data['imageUrl'],

                width:
                    double.infinity,

                height: 220,

                fit:
                    BoxFit.cover,
              ),

            Padding(

              padding:
                  const EdgeInsets.all(
                12,
              ),

              child: Column(

                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [

                  Text(

                    data['title'] ??
                        'هاتف',

                    style:
                        const TextStyle(
                      fontSize: 20,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height: 5,
                  ),

                  Text(

                    '${data['price'] ?? 0} د.ع',

                    style:
                        const TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  Text(
                    '${data['condition'] ?? ''} • سامراء',
                  ),

                  Row(

                    children: [

                      Icon(
                        likes.contains(uid)
                            ? Icons.favorite
                            : Icons.favorite_border,

                        color:
                            likes.contains(uid)
                                ? Colors.red
                                : null,
                      ),

                      const SizedBox(
                        width: 5,
                      ),

                      Text(
                        '${likes.length}',
                      ),

                      const Spacer(),

                      const Icon(
                        Icons.comment,
                      ),

                      const SizedBox(
                        width: 5,
                      ),

                      const Text(
                        'تعليقات',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ============================================================
// CREATE POST
// ============================================================

class CreatePostPage
    extends StatefulWidget {

  const CreatePostPage({
    super.key,
  });

  @override
  State<CreatePostPage> createState() =>
      _CreatePostPageState();
}

class _CreatePostPageState
    extends State<CreatePostPage> {

  final title =
      TextEditingController();

  final price =
      TextEditingController();

  final description =
      TextEditingController();

  String condition =
      'مستعمل';

  XFile? image;

  bool loading = false;


  Future<void> selectImage() async {

    final picker =
        ImagePicker();

    final selected =
        await picker.pickImage(
      source:
          ImageSource.gallery,
      imageQuality:
          80,
    );

    if (selected != null) {

      setState(() {
        image = selected;
      });
    }
  }


  Future<void> publish() async {

    if (title.text.trim().isEmpty ||
        price.text.trim().isEmpty) {

      showMessage(
        context,
        'املأ اسم الهاتف والسعر',
      );

      return;
    }

    try {

      setState(() {
        loading = true;
      });

      final uid =
          FirebaseAuth.instance
              .currentUser!
              .uid;

      String? imageUrl;

      if (image != null) {

        final path =
            'posts/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg';

        final ref =
            FirebaseStorage.instance
                .ref()
                .child(path);

        await ref.putFile(
          File(image!.path),
        );

        imageUrl =
            await ref.getDownloadURL();
      }

      await FirebaseFirestore.instance
          .collection('posts')
          .add({

        'title':
            title.text.trim(),

        'price':
            int.tryParse(
                  price.text.trim(),
                ) ??
                0,

        'description':
            description.text.trim(),

        'condition':
            condition,

        'imageUrl':
            imageUrl,

        'ownerId':
            uid,

        'city':
            'سامراء',

        'likes':
            [],

        'createdAt':
            FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      Navigator.pop(context);

    } catch (e) {

      showMessage(
        context,
        'فشل نشر الإعلان: $e',
      );

    } finally {

      setState(() {
        loading = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title:
            const Text(
          'بيع هاتف',
        ),
      ),

      body: ListView(

        padding:
            const EdgeInsets.all(16),

        children: [

          GestureDetector(

            onTap:
                selectImage,

            child:
                Container(

              height:
                  220,

              color:
                  Colors.grey.shade200,

              child:
                  image == null
                      ? const Center(
                          child: Column(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons
                                    .add_a_photo,
                                size: 50,
                              ),
                              SizedBox(
                                height: 10,
                              ),
                              Text(
                                'إضافة صورة الهاتف',
                              ),
                            ],
                          ),
                        )
                      : Image.file(
                          File(
                            image!.path,
                          ),
                          fit:
                              BoxFit.cover,
                        ),
            ),
          ),

          const SizedBox(
            height: 15,
          ),

          TextField(
            controller:
                title,
            decoration:
                const InputDecoration(
              labelText:
                  'اسم الهاتف',
              border:
                  OutlineInputBorder(),
            ),
          ),

          const SizedBox(
            height: 12,
          ),

          TextField(
            controller:
                price,
            keyboardType:
                TextInputType.number,
            decoration:
                const InputDecoration(
              labelText:
                  'السعر بالدينار',
              suffixText:
                  'د.ع',
              border:
                  OutlineInputBorder(),
            ),
          ),

          const SizedBox(
            height: 12,
          ),

          DropdownButtonFormField<String>(

            value:
                condition,

            decoration:
                const InputDecoration(
              labelText:
                  'حالة الهاتف',
              border:
                  OutlineInputBorder(),
            ),

            items: const [

              DropdownMenuItem(
                value:
                    'جديد',
                child:
                    Text('جديد'),
              ),

              DropdownMenuItem(
                value:
                    'شبه جديد',
                child:
                    Text('شبه جديد'),
              ),

              DropdownMenuItem(
                value:
                    'مستعمل',
                child:
                    Text('مستعمل'),
              ),
            ],

            onChanged:
                (value) {

              setState(() {
                condition =
                    value!;
              });
            },
          ),

          const SizedBox(
            height: 12,
          ),

          TextField(

            controller:
                description,

            maxLines:
                5,

            decoration:
                const InputDecoration(
              labelText:
                  'الوصف',
              hintText:
                  'اكتب حالة الجهاز والبطارية والذاكرة...',
              border:
                  OutlineInputBorder(),
            ),
          ),

          const SizedBox(
            height: 20,
          ),

          SizedBox(

            height:
                52,

            child:
                ElevatedButton(

              onPressed:
                  loading
                      ? null
                      : publish,

              child:
                  loading
                      ? const CircularProgressIndicator()
                      : const Text(
                          'نشر الإعلان',
                        ),
            ),
          ),
        ],
      ),
    );
  }
}


// ============================================================
// POST DETAILS
// ============================================================

class PostDetailsPage
    extends StatefulWidget {

  final String postId;

  final Map<String, dynamic> data;

  const PostDetailsPage({
    super.key,
    required this.postId,
    required this.data,
  });

  @override
  State<PostDetailsPage> createState() =>
      _PostDetailsPageState();
}

class _PostDetailsPageState
    extends State<PostDetailsPage> {

  final comment =
      TextEditingController();


  Future<void> likePost() async {

    final uid =
        FirebaseAuth.instance
            .currentUser!
            .uid;

    final ref =
        FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.postId);

    final snap =
        await ref.get();

    final likes =
        List<String>.from(
      snap.data()?['likes'] ?? [],
    );

    if (likes.contains(uid)) {

      likes.remove(uid);

    } else {

      likes.add(uid);
    }

    await ref.update({
      'likes': likes,
    });
  }


  Future<void> addComment() async {

    final text =
        comment.text.trim();

    if (text.isEmpty) return;

    final uid =
        FirebaseAuth.instance
            .currentUser!
            .uid;

    await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .collection('comments')
        .add({

      'userId':
          uid,

      'text':
          text,

      'createdAt':
          FieldValue.serverTimestamp(),
    });

    comment.clear();
  }


  @override
  Widget build(BuildContext context) {

    final post =
        widget.data;

    final currentUid =
        FirebaseAuth.instance
            .currentUser!
            .uid;

    final owner =
        post['ownerId'];

    final likes =
        List.from(
      post['likes'] ?? [],
    );

    return Scaffold(

      appBar: AppBar(
        title:
            const Text(
          'الإعلان',
        ),
      ),

      body: ListView(

        padding:
            const EdgeInsets.all(15),

        children: [

          if (post['imageUrl'] != null)

            ClipRRect(

              borderRadius:
                  BorderRadius.circular(
                15,
              ),

              child:
                  Image.network(
                post['imageUrl'],
                height: 300,
                fit:
                    BoxFit.cover,
              ),
            ),

          const SizedBox(
            height: 15,
          ),

          Text(
            post['title'] ?? '',
            style:
                const TextStyle(
              fontSize: 27,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 5,
          ),

          Text(
            '${post['price'] ?? 0} د.ع',
            style:
                const TextStyle(
              fontSize: 23,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          Text(
            'الحالة: ${post['condition'] ?? ''}',
          ),

          const SizedBox(
            height: 15,
          ),

          Text(
            post['description'] ??
                '',
            style:
                const TextStyle(
              fontSize: 17,
            ),
          ),

          Row(

            children: [

              IconButton(

                onPressed:
                    likePost,

                icon:
                    Icon(
                  likes.contains(
                    currentUid,
                  )
                      ? Icons.favorite
                      : Icons.favorite_border,

                  color:
                      likes.contains(
                    currentUid,
                  )
                          ? Colors.red
                          : null,
                ),
              ),

              Text(
                '${likes.length}',
              ),

              const Spacer(),

              if (owner != currentUid)

                ElevatedButton.icon(

                  icon:
                      const Icon(
                    Icons.message,
                  ),

                  label:
                      const Text(
                    'مراسلة البائع',
                  ),

                  onPressed: () {

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ChatPage(
                          otherUserId:
                              owner,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),

          const Divider(),

          const Text(
            'التعليقات',
            style:
                TextStyle(
              fontSize: 21,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          StreamBuilder<QuerySnapshot>(

            stream:
                FirebaseFirestore
                    .instance
                    .collection('posts')
                    .doc(widget.postId)
                    .collection('comments')
                    .orderBy(
                      'createdAt',
                    )
                    .snapshots(),

            builder:
                (context, snapshot) {

              if (!snapshot.hasData) {

                return const Padding(
                  padding:
                      EdgeInsets.all(20),
                  child:
                      CircularProgressIndicator(),
                );
              }

              return Column(

                children:
                    snapshot.data!.docs
                        .map((doc) {

                  final data =
                      doc.data()
                          as Map<String,
                              dynamic>;

                  return ListTile(

                    leading:
                        const CircleAvatar(
                      child:
                          Icon(Icons.person),
                    ),

                    title:
                        Text(
                      data['text'] ??
                          '',
                    ),
                  );

                }).toList(),
              );
            },
          ),

          Row(

            children: [

              Expanded(

                child:
                    TextField(

                  controller:
                      comment,

                  decoration:
                      const InputDecoration(
                    hintText:
                        'اكتب تعليق...',
                    border:
                        OutlineInputBorder(),
                  ),
                ),
              ),

              IconButton(

                onPressed:
                    addComment,

                icon:
                    const Icon(
                  Icons.send,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


// ============================================================
// CHAT LIST
// ============================================================

class ChatsListPage
    extends StatelessWidget {

  const ChatsListPage({
    super.key,
  });

  @override
  Widget build(BuildContext context) {

    final uid =
        FirebaseAuth.instance
            .currentUser!
            .uid;

    return Scaffold(

      appBar: AppBar(
        title:
            const Text(
          'الرسائل',
        ),
      ),

      body:
          StreamBuilder<QuerySnapshot>(

        stream:
            FirebaseFirestore.instance
                .collection('chats')
                .where(
                  'members',
                  arrayContains:
                      uid,
                )
                .orderBy(
                  'updatedAt',
                  descending:
                      true,
                )
                .snapshots(),

        builder:
            (context, snapshot) {

          if (!snapshot.hasData) {

            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          final chats =
              snapshot.data!.docs;

          if (chats.isEmpty) {

            return const Center(
              child:
                  Text(
                'ما عندك محادثات',
              ),
            );
          }

          return ListView.builder(

            itemCount:
                chats.length,

            itemBuilder:
                (context, index) {

              final chat =
                  chats[index].data()
                      as Map<String,
                          dynamic>;

              final members =
                  List.from(
                chat['members'] ?? [],
              );

              final other =
                  members.firstWhere(
                (id) => id != uid,
              );

              return ListTile(

                leading:
                    const CircleAvatar(
                  child:
                      Icon(Icons.person),
                ),

                title:
                    FutureBuilder<
                        DocumentSnapshot>(

                  future:
                      FirebaseFirestore
                          .instance
                          .collection(
                            'users',
                          )
                          .doc(other)
                          .get(),

                  builder:
                      (context, user) {

                    if (!user.hasData) {

                      return const Text(
                        'المستخدم',
                      );
                    }

                    final data =
                        user.data!.data()
                            as Map<String,
                                dynamic>?;

                    return Text(
                      data?['username'] ??
                          'المستخدم',
                    );
                  },
                ),

                subtitle:
                    Text(
                  chat['lastMessage'] ??
                      '',
                ),

                onTap: () {

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ChatPage(
                        otherUserId:
                            other,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}


// ============================================================
// CHAT
// ============================================================

class ChatPage
    extends StatefulWidget {

  final String otherUserId;

  const ChatPage({
    super.key,
    required this.otherUserId,
  });

  @override
  State<ChatPage> createState() =>
      _ChatPageState();
}

class _ChatPageState
    extends State<ChatPage> {

  final controller =
      TextEditingController();

  String get chatId {

    final current =
        FirebaseAuth.instance
            .currentUser!
            .uid;

    final other =
        widget.otherUserId;

    return current.compareTo(other) < 0
        ? '${current}_$other'
        : '${other}_$current';
  }


  Future<void> send() async {

    final text =
        controller.text.trim();

    if (text.isEmpty) return;

    final uid =
        FirebaseAuth.instance
            .currentUser!
            .uid;

    final chat =
        FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId);

    await chat.set({

      'members': [
        uid,
        widget.otherUserId,
      ],

      'lastMessage':
          text,

      'updatedAt':
          FieldValue.serverTimestamp(),

    }, SetOptions(
      merge: true,
    ));

    await chat
        .collection('messages')
        .add({

      'senderId':
          uid,

      'receiverId':
          widget.otherUserId,

      'text':
          text,

      'createdAt':
          FieldValue.serverTimestamp(),
    });

    controller.clear();
  }


  @override
  Widget build(BuildContext context) {

    final uid =
        FirebaseAuth.instance
            .currentUser!
            .uid;

    return Scaffold(

      appBar: AppBar(
        title:
            const Text(
          'المحادثة',
        ),
      ),

      body: Column(

        children: [

          Expanded(

            child:
                StreamBuilder<QuerySnapshot>(

              stream:
                  FirebaseFirestore.instance
                      .collection('chats')
                      .doc(chatId)
                      .collection('messages')
                      .orderBy(
                        'createdAt',
                      )
                      .snapshots(),

              builder:
                  (context, snapshot) {

                if (!snapshot.hasData) {

                  return const Center(
                    child:
                        CircularProgressIndicator(),
                  );
                }

                final messages =
                    snapshot.data!.docs;

                return ListView.builder(

                  padding:
                      const EdgeInsets.all(
                    12,
                  ),

                  itemCount:
                      messages.length,

                  itemBuilder:
                      (context, index) {

                    final message =
                        messages[index]
                            .data()
                            as Map<String,
                                dynamic>;

                    final mine =
                        message['senderId'] ==
                            uid;

                    return Align(

                      alignment:
                          mine
                              ? Alignment
                                  .centerRight
                              : Alignment
                                  .centerLeft,

                      child:
                          Container(

                        margin:
                            const EdgeInsets
                                .symmetric(
                          vertical: 4,
                        ),

                        padding:
                            const EdgeInsets
                                .all(12),

                        constraints:
                            const BoxConstraints(
                          maxWidth: 280,
                        ),

                        decoration:
                            BoxDecoration(

                          color:
                              mine
                                  ? Colors
                                      .green
                                      .shade100
                                  : Colors
                                      .grey
                                      .shade200,

                          borderRadius:
                              BorderRadius
                                  .circular(
                            15,
                          ),
                        ),

                        child:
                            Text(
                          message['text'] ??
                              '',
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          SafeArea(

            child:
                Padding(

              padding:
                  const EdgeInsets.all(8),

              child:
                  Row(

                children: [

                  Expanded(

                    child:
                        TextField(

                      controller:
                          controller,

                      decoration:
                          const InputDecoration(
                        hintText:
                            'اكتب رسالة...',
                        border:
                            OutlineInputBorder(),
                      ),
                    ),
                  ),

                  IconButton(

                    onPressed:
                        send,

                    icon:
                        const Icon(
                      Icons.send,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// ============================================================
// PROFILE
// ============================================================

class ProfilePage
    extends StatelessWidget {

  const ProfilePage({
    super.key,
  });

  @override
  Widget build(BuildContext context) {

    final user =
        FirebaseAuth.instance
            .currentUser;

    return Scaffold(

      appBar: AppBar(
        title:
            const Text(
          'حسابي',
        ),
      ),

      body:
          FutureBuilder<DocumentSnapshot>(

        future:
            FirebaseFirestore.instance
                .collection('users')
                .doc(user!.uid)
                .get(),

        builder:
            (context, snapshot) {

          if (!snapshot.hasData) {

            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          final data =
              snapshot.data!.data()
                  as Map<String,
                      dynamic>?;

          return ListView(

            padding:
                const EdgeInsets.all(20),

            children: [

              CircleAvatar(

                radius: 50,

                backgroundImage:
                    user.photoURL != null
                        ? NetworkImage(
                            user.photoURL!,
                          )
                        : null,

                child:
                    user.photoURL == null
                        ? const Icon(
                            Icons.person,
                            size: 50,
                          )
                        : null,
              ),

              const SizedBox(
                height: 15,
              ),

              Center(

                child:
                    Text(

                  '@${data?['username'] ?? ''}',

                  style:
                      const TextStyle(
                    fontSize: 22,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(
                height: 10,
              ),

              Center(
                child:
                    Text(
                  user.email ?? '',
                ),
              ),

              const SizedBox(
                height: 30,
              ),

              ElevatedButton.icon(

                icon:
                    const Icon(
                  Icons.logout,
                ),

                label:
                    const Text(
                  'تسجيل الخروج',
                ),

                onPressed: () async {

                  await GoogleSignIn()
                      .signOut();

                  await FacebookAuth
                      .instance
                      .logOut();

                  await FirebaseAuth
                      .instance
                      .signOut();
                },
              ),
            ],
          );
        },
      ),
    );
  }
}


// ============================================================
// SEARCH
// ============================================================

class PhoneSearchDelegate
    extends SearchDelegate {

  @override
  List<Widget>? buildActions(
      BuildContext context) {

    return [

      IconButton(

        icon:
            const Icon(
          Icons.clear,
        ),

        onPressed: () {
          query = '';
        },
      ),
    ];
  }


  @override
  Widget? buildLeading(
      BuildContext context) {

    return IconButton(

      icon:
          const Icon(
        Icons.arrow_back,
      ),

      onPressed: () {
        close(
          context,
          null,
        );
      },
    );
  }


  @override
  Widget buildResults(
      BuildContext context) {

    return StreamBuilder<QuerySnapshot>(

      stream:
          FirebaseFirestore.instance
              .collection('posts')
              .orderBy(
                'createdAt',
                descending:
                    true,
              )
              .snapshots(),

      builder:
          (context, snapshot) {

        if (!snapshot.hasData) {

          return const Center(
            child:
                CircularProgressIndicator(),
          );
        }

        final posts =
            snapshot.data!.docs.where(
          (doc) {

            final data =
                doc.data()
                    as Map<String,
                        dynamic>;

            final title =
                (data['title'] ??
                        '')
                    .toString()
                    .toLowerCase();

            return title.contains(
              query.toLowerCase(),
            );
          },
        ).toList();

        return ListView.builder(

          itemCount:
              posts.length,

          itemBuilder:
              (context, index) {

            final data =
                posts[index].data()
                    as Map<String,
                        dynamic>;

            return ListTile(

              leading:
                  data['imageUrl'] != null
                      ? Image.network(
                          data['imageUrl'],
                          width: 60,
                          fit:
                              BoxFit.cover,
                        )
                      : const Icon(
                          Icons.phone_android,
                        ),

              title:
                  Text(
                data['title'] ??
                    '',
              ),

              subtitle:
                  Text(
                '${data['price'] ?? 0} د.ع',
              ),

              onTap: () {

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        PostDetailsPage(
                      postId:
                          posts[index].id,
                      data:
                          data,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }


  @override
  Widget buildSuggestions(
      BuildContext context) {

    return const Center(
      child:
          Text(
        'ابحث عن iPhone أو Samsung أو أي هاتف',
      ),
    );
  }
}


// ============================================================
// HELPER
// ============================================================

void showMessage(
  BuildContext context,
  String message,
) {

  ScaffoldMessenger.of(context)
      .showSnackBar(
    SnackBar(
      content:
          Text(message),
    ),
  );
}