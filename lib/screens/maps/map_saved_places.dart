import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MapSavedPlaces extends StatefulWidget {
  const MapSavedPlaces({
    super.key,
  });

  @override
  State<MapSavedPlaces> createState() =>
      _MapSavedPlacesState();
}

class _MapSavedPlacesState
    extends State<MapSavedPlaces> {
  // ============================================================
  // FIREBASE
  // ============================================================

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController _searchController =
      TextEditingController();

  // ============================================================
  // STATE
  // ============================================================

  bool _loading = true;

  bool _searching = false;

  String _selectedCategory = 'All';

  List<_SavedPlace> _places = [];

  List<_SavedPlace> _filteredPlaces = [];

  // ============================================================
  // COLORS
  // ============================================================

  static const Color background =
      Color(0xff070C16);

  static const Color panel =
      Color(0xff101827);

  static const Color panel2 =
      Color(0xff0D1421);

  static const Color purple =
      Color(0xff8A3DFF);

  static const Color cyan =
      Color(0xff00E5FF);

  static const Color pink =
      Color(0xffFF3D81);

  static const Color green =
      Color(0xff00D68F);

  static const Color orange =
      Color(0xffFFB020);

  // ============================================================
  // CATEGORIES
  // ============================================================

  final List<String> _categories = [
    'All',
    'Home',
    'Work',
    'Favorites',
    'Other',
  ];

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _searchController.addListener(
      _filterPlaces,
    );

    _loadSavedPlaces();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _searchController.dispose();

    super.dispose();
  }

  // ============================================================
  // LOAD SAVED PLACES
  // ============================================================

  Future<void> _loadSavedPlaces() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final user =
          _auth.currentUser;

      if (user == null) {
        if (!mounted) {
          return;
        }

        setState(() {
          _places = [];
          _filteredPlaces = [];
          _loading = false;
        });

        return;
      }

      final snapshot =
          await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('saved_places')
              .orderBy(
                'createdAt',
                descending: true,
              )
              .get();

      final places =
          snapshot.docs.map(
        (document) {
          final data =
              document.data();

          return _SavedPlace.fromMap(
            document.id,
            data,
          );
        },
      ).toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _places = places;

        _filteredPlaces =
            List<_SavedPlace>.from(
          places,
        );

        _loading = false;
      });

      _filterPlaces();
    } catch (e) {
      // --------------------------------------------------------
      // FALLBACK
      //
      // If createdAt does not exist on some old documents,
      // try loading without orderBy.
      // --------------------------------------------------------

      try {
        await _loadSavedPlacesWithoutOrdering();
      } catch (_) {
        if (!mounted) {
          return;
        }

        setState(() {
          _places = [];
          _filteredPlaces = [];
          _loading = false;
        });
      }
    }
  }

  // ============================================================
  // FALLBACK LOAD
  // ============================================================

  Future<void>
      _loadSavedPlacesWithoutOrdering() async {
    final user =
        _auth.currentUser;

    if (user == null) {
      return;
    }

    final snapshot =
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('saved_places')
            .get();

    final places =
        snapshot.docs.map(
      (document) {
        return _SavedPlace.fromMap(
          document.id,
          document.data(),
        );
      },
    ).toList();

    if (!mounted) {
      return;
    }

    setState(() {
      _places = places;

      _filteredPlaces =
          List<_SavedPlace>.from(
        places,
      );

      _loading = false;
    });

    _filterPlaces();
  }

  // ============================================================
  // FILTER
  // ============================================================

  void _filterPlaces() {
    final search =
        _searchController.text
            .trim()
            .toLowerCase();

    List<_SavedPlace> result =
        List<_SavedPlace>.from(
      _places,
    );

    if (_selectedCategory !=
        'All') {
      result = result.where(
        (place) {
          return place.category
                  .toLowerCase() ==
              _selectedCategory
                  .toLowerCase();
        },
      ).toList();
    }

    if (search.isNotEmpty) {
      result = result.where(
        (place) {
          final name =
              place.name
                  .toLowerCase();

          final address =
              place.address
                  .toLowerCase();

          final category =
              place.category
                  .toLowerCase();

          return name.contains(
                search,
              ) ||
              address.contains(
                search,
              ) ||
              category.contains(
                search,
              );
        },
      ).toList();
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _filteredPlaces = result;
    });
  }

  // ============================================================
  // CATEGORY
  // ============================================================

  void _selectCategory(
    String category,
  ) {
    setState(() {
      _selectedCategory =
          category;
    });

    _filterPlaces();
  }

  // ============================================================
  // ADD PLACE
  // ============================================================

  void _showAddPlace() {
    final nameController =
        TextEditingController();

    final addressController =
        TextEditingController();

    final latitudeController =
        TextEditingController();

    final longitudeController =
        TextEditingController();

    String category =
        'Favorites';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          Colors.transparent,
      builder: (
        context,
      ) {
        return StatefulBuilder(
          builder: (
            context,
            setSheetState,
          ) {
            return Padding(
              padding:
                  EdgeInsets.only(
                bottom:
                    MediaQuery.of(
                  context,
                ).viewInsets.bottom,
              ),
              child: Container(
                padding:
                    const EdgeInsets.fromLTRB(
                  20,
                  14,
                  20,
                  24,
                ),
                decoration:
                    const BoxDecoration(
                  color: panel,
                  borderRadius:
                      BorderRadius.vertical(
                    top:
                        Radius.circular(
                      28,
                    ),
                  ),
                ),
                child:
                    SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Center(
                        child:
                            Container(
                          width: 38,
                          height: 4,
                          decoration:
                              BoxDecoration(
                            color:
                                Colors.white24,
                            borderRadius:
                                BorderRadius
                                    .circular(
                              10,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 18,
                      ),

                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration:
                                BoxDecoration(
                              color:
                                  cyan.withValues(
                                alpha:
                                    .10,
                              ),
                              shape:
                                  BoxShape
                                      .circle,
                            ),
                            child:
                                const Icon(
                              Icons
                                  .add_location_alt_rounded,
                              color:
                                  cyan,
                              size: 21,
                            ),
                          ),

                          const SizedBox(
                            width: 10,
                          ),

                          const Expanded(
                            child:
                                Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              children: [
                                Text(
                                  'Save a place',
                                  style:
                                      TextStyle(
                                    color:
                                        Colors.white,
                                    fontSize:
                                        16,
                                    fontWeight:
                                        FontWeight
                                            .w700,
                                  ),
                                ),
                                Text(
                                  'Keep a location ready for later',
                                  style:
                                      TextStyle(
                                    color:
                                        Colors.white38,
                                    fontSize:
                                        9,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(
                        height: 20,
                      ),

                      _inputField(
                        controller:
                            nameController,
                        label:
                            'Place name',
                        hint:
                            'e.g. My favorite restaurant',
                        icon:
                            Icons.place_rounded,
                      ),

                      const SizedBox(
                        height: 10,
                      ),

                      _inputField(
                        controller:
                            addressController,
                        label:
                            'Address',
                        hint:
                            'Enter an address',
                        icon:
                            Icons
                                .location_on_rounded,
                      ),

                      const SizedBox(
                        height: 10,
                      ),

                      Row(
                        children: [
                          Expanded(
                            child:
                                _inputField(
                              controller:
                                  latitudeController,
                              label:
                                  'Latitude',
                              hint:
                                  '-26.2041',
                              icon:
                                  Icons
                                      .north_rounded,
                              keyboardType:
                                  const TextInputType
                                      .numberWithOptions(
                                decimal:
                                    true,
                                signed:
                                    true,
                              ),
                            ),
                          ),

                          const SizedBox(
                            width: 9,
                          ),

                          Expanded(
                            child:
                                _inputField(
                              controller:
                                  longitudeController,
                              label:
                                  'Longitude',
                              hint:
                                  '28.0473',
                              icon:
                                  Icons
                                      .east_rounded,
                              keyboardType:
                                  const TextInputType
                                      .numberWithOptions(
                                decimal:
                                    true,
                                signed:
                                    true,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(
                        height: 16,
                      ),

                      const Text(
                        'Category',
                        style:
                            TextStyle(
                          color:
                              Colors.white70,
                          fontSize:
                              10,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),

                      const SizedBox(
                        height: 8,
                      ),

                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children:
                            _categories
                                .where(
                          (
                            item,
                          ) =>
                              item !=
                              'All',
                        )
                                .map(
                          (
                            item,
                          ) {
                            final selected =
                                category ==
                                    item;

                            return GestureDetector(
                              onTap:
                                  () {
                                setSheetState(
                                  () {
                                    category =
                                        item;
                                  },
                                );
                              },
                              child:
                                  Container(
                                padding:
                                    const EdgeInsets
                                        .symmetric(
                                  horizontal:
                                      12,
                                  vertical:
                                      8,
                                ),
                                decoration:
                                    BoxDecoration(
                                  color: selected
                                      ? purple.withValues(
                                          alpha:
                                              .15,
                                        )
                                      : Colors
                                          .transparent,
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    13,
                                  ),
                                  border:
                                      Border.all(
                                    color:
                                        selected
                                            ? purple.withValues(
                                                alpha:
                                                    .40,
                                              )
                                            : Colors
                                                .white10,
                                  ),
                                ),
                                child:
                                    Text(
                                  item,
                                  style:
                                      TextStyle(
                                    color: selected
                                        ? Colors
                                            .white
                                        : Colors
                                            .white54,
                                    fontSize:
                                        10,
                                    fontWeight:
                                        selected
                                            ? FontWeight
                                                .w700
                                            : FontWeight
                                                .w500,
                                  ),
                                ),
                              ),
                            );
                          },
                        ).toList(),
                      ),

                      const SizedBox(
                        height: 20,
                      ),

                      SizedBox(
                        width:
                            double.infinity,
                        height: 48,
                        child:
                            ElevatedButton(
                          onPressed:
                              () async {
                            await _savePlace(
                              name:
                                  nameController
                                      .text
                                      .trim(),
                              address:
                                  addressController
                                      .text
                                      .trim(),
                              latitude:
                                  double.tryParse(
                                latitudeController
                                    .text
                                    .trim(),
                              ),
                              longitude:
                                  double.tryParse(
                                longitudeController
                                    .text
                                    .trim(),
                              ),
                              category:
                                  category,
                            );

                            if (context
                                .mounted) {
                              Navigator.pop(
                                context,
                              );
                            }
                          },
                          style:
                              ElevatedButton
                                  .styleFrom(
                            backgroundColor:
                                purple,
                            foregroundColor:
                                Colors.white,
                            elevation:
                                0,
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                15,
                              ),
                            ),
                          ),
                          child:
                              const Text(
                            'Save Place',
                            style:
                                TextStyle(
                              fontSize:
                                  12,
                              fontWeight:
                                  FontWeight
                                      .w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(
      () {
        nameController.dispose();
        addressController.dispose();
        latitudeController.dispose();
        longitudeController.dispose();
      },
    );
  }

  // ============================================================
  // SAVE PLACE
  // ============================================================

  Future<void> _savePlace({
    required String name,
    required String address,
    required double? latitude,
    required double? longitude,
    required String category,
  }) async {
    if (name.isEmpty) {
      _showMessage(
        'Enter a name for the place.',
      );

      return;
    }

    if (latitude == null ||
        longitude == null) {
      _showMessage(
        'Enter valid latitude and longitude.',
      );

      return;
    }

    if (latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      _showMessage(
        'The coordinates are not valid.',
      );

      return;
    }

    final user =
        _auth.currentUser;

    if (user == null) {
      _showMessage(
        'Please sign in first.',
      );

      return;
    }

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('saved_places')
          .add({
        'name': name,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'category': category,
        'createdAt':
            FieldValue.serverTimestamp(),
      });

      await _loadSavedPlaces();

      _showMessage(
        'Place saved to ChattªX Maps.',
      );
    } catch (e) {
      _showMessage(
        'Could not save this place.',
      );
    }
  }

  // ============================================================
  // DELETE PLACE
  // ============================================================

  Future<void> _deletePlace(
    _SavedPlace place,
  ) async {
    final user =
        _auth.currentUser;

    if (user == null) {
      return;
    }

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('saved_places')
          .doc(place.id)
          .delete();

      if (!mounted) {
        return;
      }

      setState(() {
        _places.removeWhere(
          (
            item,
          ) =>
              item.id ==
              place.id,
        );
      });

      _filterPlaces();

      _showMessage(
        'Place removed.',
      );
    } catch (e) {
      _showMessage(
        'Could not remove the place.',
      );
    }
  }

  // ============================================================
  // DELETE CONFIRMATION
  // ============================================================

  void _confirmDelete(
    _SavedPlace place,
  ) {
    showDialog(
      context: context,
      builder: (
        context,
      ) {
        return AlertDialog(
          backgroundColor:
              panel,
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              20,
            ),
          ),
          title: const Text(
            'Remove saved place?',
            style:
                TextStyle(
              color:
                  Colors.white,
              fontSize:
                  16,
              fontWeight:
                  FontWeight.w700,
            ),
          ),
          content: Text(
            'Remove "${place.name}" from your saved places?',
            style:
                const TextStyle(
              color:
                  Colors.white54,
              fontSize:
                  11,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                );
              },
              child: const Text(
                'Cancel',
                style:
                    TextStyle(
                  color:
                      Colors.white54,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                );

                _deletePlace(
                  place,
                );
              },
              child: const Text(
                'Remove',
                style:
                    TextStyle(
                  color:
                      pink,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // PLACE DETAILS
  // ============================================================

  void _showPlaceDetails(
    _SavedPlace place,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor:
          Colors.transparent,
      builder: (_) {
        return Container(
          padding:
              const EdgeInsets.fromLTRB(
            20,
            14,
            20,
            25,
          ),
          decoration:
              const BoxDecoration(
            color: panel,
            borderRadius:
                BorderRadius.vertical(
              top:
                  Radius.circular(
                27,
              ),
            ),
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment
                    .start,
            children: [
              Center(
                child:
                    Container(
                  width: 38,
                  height: 4,
                  decoration:
                      BoxDecoration(
                    color:
                        Colors.white24,
                    borderRadius:
                        BorderRadius
                            .circular(
                      10,
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 17,
              ),

              Row(
                children: [
                  _categoryIcon(
                    place.category,
                    size: 48,
                  ),

                  const SizedBox(
                    width: 11,
                  ),

                  Expanded(
                    child:
                        Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Text(
                          place.name,
                          maxLines:
                              1,
                          overflow:
                              TextOverflow
                                  .ellipsis,
                          style:
                              const TextStyle(
                            color:
                                Colors.white,
                            fontSize:
                                16,
                            fontWeight:
                                FontWeight
                                    .w700,
                          ),
                        ),

                        const SizedBox(
                          height: 3,
                        ),

                        Text(
                          place.category,
                          style:
                              const TextStyle(
                            color:
                                cyan,
                            fontSize:
                                9,
                            fontWeight:
                                FontWeight
                                    .w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 17,
              ),

              if (place.address
                  .isNotEmpty)
                _detailRow(
                  icon:
                      Icons.location_on_rounded,
                  text:
                      place.address,
                ),

              _detailRow(
                icon:
                    Icons.my_location_rounded,
                text:
                    '${place.latitude.toStringAsFixed(6)}, ${place.longitude.toStringAsFixed(6)}',
              ),

              const SizedBox(
                height: 18,
              ),

              Row(
                children: [
                  Expanded(
                    child:
                        _actionButton(
                      icon:
                          Icons.directions_rounded,
                      title:
                          'Directions',
                      color:
                          green,
                      onTap:
                          () {
                        Navigator.pop(
                          context,
                        );

                        _showMessage(
                          'Directions will connect to ChattªX Maps navigation.',
                        );
                      },
                    ),
                  ),

                  const SizedBox(
                    width: 8,
                  ),

                  _actionButton(
                    icon:
                        Icons.delete_outline_rounded,
                    title:
                        'Delete',
                    color:
                        pink,
                    onTap:
                        () {
                      Navigator.pop(
                        context,
                      );

                      _confirmDelete(
                        place,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // INPUT
  // ============================================================

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style:
              const TextStyle(
            color:
                Colors.white70,
            fontSize: 10,
            fontWeight:
                FontWeight.w600,
          ),
        ),

        const SizedBox(
          height: 6,
        ),

        Container(
          height: 48,
          padding:
              const EdgeInsets.symmetric(
            horizontal: 12,
          ),
          decoration:
              BoxDecoration(
            color:
                panel2,
            borderRadius:
                BorderRadius.circular(
              14,
            ),
            border: Border.all(
              color:
                  Colors.white10,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color:
                    cyan,
                size: 17,
              ),

              const SizedBox(
                width: 8,
              ),

              Expanded(
                child:
                    TextField(
                  controller:
                      controller,
                  keyboardType:
                      keyboardType,
                  style:
                      const TextStyle(
                    color:
                        Colors.white,
                    fontSize:
                        11,
                  ),
                  cursorColor:
                      cyan,
                  decoration:
                      InputDecoration(
                    border:
                        InputBorder.none,
                    hintText:
                        hint,
                    hintStyle:
                        const TextStyle(
                      color:
                          Colors.white24,
                      fontSize:
                          10,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // CATEGORY ICON
  // ============================================================

  Widget _categoryIcon(
    String category, {
    double size = 42,
  }) {
    IconData icon =
        Icons.place_rounded;

    Color color =
        cyan;

    switch (
        category.toLowerCase()) {
      case 'home':
        icon =
            Icons.home_rounded;
        color =
            green;
        break;

      case 'work':
        icon =
            Icons.work_rounded;
        color =
            purple;
        break;

      case 'favorites':
        icon =
            Icons.favorite_rounded;
        color =
            pink;
        break;

      case 'other':
        icon =
            Icons.place_rounded;
        color =
            orange;
        break;
    }

    return Container(
      width: size,
      height: size,
      decoration:
          BoxDecoration(
        color:
            color.withValues(
          alpha: .10,
        ),
        borderRadius:
            BorderRadius.circular(
          size * .30,
        ),
        border: Border.all(
          color:
              color.withValues(
            alpha: .22,
          ),
        ),
      ),
      child: Icon(
        icon,
        color: color,
        size:
            size * .42,
      ),
    );
  }

  // ============================================================
  // DETAIL ROW
  // ============================================================

  Widget _detailRow({
    required IconData icon,
    required String text,
  }) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 9,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment
                .start,
        children: [
          Icon(
            icon,
            color:
                cyan,
            size: 16,
          ),

          const SizedBox(
            width: 9,
          ),

          Expanded(
            child: Text(
              text,
              style:
                  const TextStyle(
                color:
                    Colors.white54,
                fontSize:
                    10,
                height:
                    1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ACTION BUTTON
  // ============================================================

  Widget _actionButton({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        padding:
            const EdgeInsets.symmetric(
          horizontal: 14,
        ),
        decoration:
            BoxDecoration(
          color:
              color.withValues(
            alpha: .10,
          ),
          borderRadius:
              BorderRadius.circular(
            14,
          ),
          border: Border.all(
            color:
                color.withValues(
              alpha: .24,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color:
                  color,
              size: 17,
            ),

            const SizedBox(
              width: 6,
            ),

            Text(
              title,
              style:
                  TextStyle(
                color:
                    Colors.white,
                fontSize:
                    10,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PLACE TILE
  // ============================================================

  Widget _placeTile(
    _SavedPlace place,
  ) {
    return Dismissible(
      key: ValueKey(
        place.id,
      ),
      direction:
          DismissDirection.endToStart,
      confirmDismiss:
          (_) async {
        _confirmDelete(
          place,
        );

        return false;
      },
      background:
          Container(
        margin:
            const EdgeInsets.only(
          bottom: 8,
        ),
        padding:
            const EdgeInsets.only(
          right: 20,
        ),
        decoration:
            BoxDecoration(
          color:
              pink.withValues(
            alpha: .12,
          ),
          borderRadius:
              BorderRadius.circular(
            17,
          ),
        ),
        alignment:
            Alignment.centerRight,
        child:
            const Icon(
          Icons.delete_outline_rounded,
          color:
              pink,
        ),
      ),
      child: GestureDetector(
        onTap: () {
          _showPlaceDetails(
            place,
          );
        },
        child: Container(
          margin:
              const EdgeInsets.only(
            bottom: 8,
          ),
          padding:
              const EdgeInsets.all(
            10,
          ),
          decoration:
              BoxDecoration(
            color:
                panel2,
            borderRadius:
                BorderRadius.circular(
              17,
            ),
            border: Border.all(
              color:
                  Colors.white10,
            ),
          ),
          child: Row(
            children: [
              _categoryIcon(
                place.category,
              ),

              const SizedBox(
                width: 10,
              ),

              Expanded(
                child:
                    Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      place.name,
                      maxLines:
                          1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          const TextStyle(
                        color:
                            Colors.white,
                        fontSize:
                            12,
                        fontWeight:
                            FontWeight
                                .w700,
                      ),
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    if (place.address
                        .isNotEmpty)
                      Text(
                        place.address,
                        maxLines:
                            1,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style:
                            const TextStyle(
                          color:
                              Colors.white38,
                          fontSize:
                              9,
                        ),
                      ),

                    const SizedBox(
                      height: 4,
                    ),

                    Text(
                      place.category,
                      style:
                          const TextStyle(
                        color:
                            cyan,
                        fontSize:
                            8,
                        fontWeight:
                            FontWeight
                                .w600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                width: 6,
              ),

              const Icon(
                Icons
                    .chevron_right_rounded,
                color:
                    Colors.white24,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 30,
        ),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration:
                  BoxDecoration(
                color:
                    purple.withValues(
                  alpha: .10,
                ),
                shape:
                    BoxShape.circle,
                border:
                    Border.all(
                  color:
                      purple.withValues(
                    alpha: .22,
                  ),
                ),
              ),
              child:
                  const Icon(
                Icons
                    .bookmark_outline_rounded,
                color:
                    cyan,
                size: 31,
              ),
            ),

            const SizedBox(
              height: 16,
            ),

            const Text(
              'No saved places yet',
              style:
                  TextStyle(
                color:
                    Colors.white,
                fontSize:
                    15,
                fontWeight:
                    FontWeight.w700,
              ),
            ),

            const SizedBox(
              height: 6,
            ),

            const Text(
              'Save places you visit often so you can find them quickly later.',
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                color:
                    Colors.white38,
                fontSize:
                    10,
                height:
                    1.4,
              ),
            ),

            const SizedBox(
              height: 18,
            ),

            GestureDetector(
              onTap:
                  _showAddPlace,
              child:
                  Container(
                height: 43,
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal:
                      17,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      purple,
                  borderRadius:
                      BorderRadius
                          .circular(
                    14,
                  ),
                ),
                child:
                    const Row(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    Icon(
                      Icons
                          .add_location_alt_rounded,
                      color:
                          Colors.white,
                      size:
                          17,
                    ),
                    SizedBox(
                      width: 7,
                    ),
                    Text(
                      'Save a place',
                      style:
                          TextStyle(
                        color:
                            Colors.white,
                        fontSize:
                            11,
                        fontWeight:
                            FontWeight
                                .w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).hideCurrentSnackBar();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style:
              const TextStyle(
            color:
                Colors.white,
            fontSize:
                11,
          ),
        ),
        backgroundColor:
            panel,
        behavior:
            SnackBarBehavior
                .floating,
        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(
            13,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // MAIN BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          background,

      body: SafeArea(
        child: Column(
          children: [
            // ==================================================
            // HEADER
            // ==================================================

            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                14,
                12,
                14,
                10,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(
                        context,
                      );
                    },
                    child:
                        Container(
                      width: 46,
                      height: 46,
                      decoration:
                          BoxDecoration(
                        color:
                            panel,
                        shape:
                            BoxShape
                                .circle,
                        border:
                            Border.all(
                          color:
                              purple.withValues(
                            alpha:
                                .30,
                          ),
                        ),
                      ),
                      child:
                          const Icon(
                        Icons
                            .arrow_back_rounded,
                        color:
                            Colors.white,
                        size:
                            21,
                      ),
                    ),
                  ),

                  const SizedBox(
                    width: 10,
                  ),

                  Expanded(
                    child:
                        Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        const Text(
                          'Saved Places',
                          style:
                              TextStyle(
                            color:
                                Colors.white,
                            fontSize:
                                17,
                            fontWeight:
                                FontWeight
                                    .w700,
                          ),
                        ),

                        const SizedBox(
                          height: 2,
                        ),

                        Text(
                          '${_places.length} saved ${_places.length == 1 ? 'place' : 'places'}',
                          style:
                              const TextStyle(
                            color:
                                Colors.white38,
                            fontSize:
                                9,
                          ),
                        ),
                      ],
                    ),
                  ),

                  GestureDetector(
                    onTap:
                        _showAddPlace,
                    child:
                        Container(
                      width: 42,
                      height: 42,
                      decoration:
                          BoxDecoration(
                        color:
                            purple.withValues(
                          alpha:
                              .13,
                        ),
                        shape:
                            BoxShape
                                .circle,
                        border:
                            Border.all(
                          color:
                              purple.withValues(
                            alpha:
                                .30,
                          ),
                        ),
                      ),
                      child:
                          const Icon(
                        Icons
                            .add_location_alt_rounded,
                        color:
                            cyan,
                        size:
                            20,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ==================================================
            // SEARCH
            // ==================================================

            Padding(
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 14,
              ),
              child:
                  Container(
                height: 46,
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal:
                      13,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      panel,
                  borderRadius:
                      BorderRadius
                          .circular(
                    16,
                  ),
                  border:
                      Border.all(
                    color:
                        purple.withValues(
                      alpha:
                          .20,
                    ),
                  ),
                ),
                child:
                    Row(
                  children: [
                    const Icon(
                      Icons
                          .search_rounded,
                      color:
                          cyan,
                      size:
                          19,
                    ),

                    const SizedBox(
                      width:
                          8,
                    ),

                    Expanded(
                      child:
                          TextField(
                        controller:
                            _searchController,
                        style:
                            const TextStyle(
                          color:
                              Colors.white,
                          fontSize:
                              11,
                        ),
                        cursorColor:
                            cyan,
                        decoration:
                            const InputDecoration(
                          border:
                              InputBorder
                                  .none,
                          hintText:
                              'Search saved places',
                          hintStyle:
                              TextStyle(
                            color:
                                Colors.white30,
                            fontSize:
                                10,
                          ),
                        ),
                      ),
                    ),

                    if (_searchController
                        .text
                        .isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchController
                              .clear();
                        },
                        child:
                            const Icon(
                          Icons
                              .close_rounded,
                          color:
                              Colors.white38,
                          size:
                              17,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ==================================================
            // CATEGORIES
            // ==================================================

            const SizedBox(
              height: 11,
            ),

            SizedBox(
              height: 34,
              child:
                  ListView.builder(
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal:
                      14,
                ),
                scrollDirection:
                    Axis.horizontal,
                physics:
                    const BouncingScrollPhysics(),
                itemCount:
                    _categories.length,
                itemBuilder:
                    (
                  context,
                  index,
                ) {
                  final category =
                      _categories[
                          index];

                  final selected =
                      _selectedCategory ==
                          category;

                  return GestureDetector(
                    onTap: () {
                      _selectCategory(
                        category,
                      );
                    },
                    child:
                        AnimatedContainer(
                      duration:
                          const Duration(
                        milliseconds:
                            160,
                      ),
                      margin:
                          const EdgeInsets
                              .only(
                        right:
                            7,
                      ),
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal:
                            13,
                      ),
                      decoration:
                          BoxDecoration(
                        color: selected
                            ? purple
                                .withValues(
                                alpha:
                                    .16,
                              )
                            : panel,
                        borderRadius:
                            BorderRadius
                                .circular(
                          14,
                        ),
                        border:
                            Border.all(
                          color: selected
                              ? purple
                                  .withValues(
                                  alpha:
                                      .40,
                                )
                              : Colors
                                  .white10,
                        ),
                      ),
                      child:
                          Center(
                        child:
                            Text(
                          category,
                          style:
                              TextStyle(
                            color: selected
                                ? Colors
                                    .white
                                : Colors
                                    .white54,
                            fontSize:
                                9,
                            fontWeight:
                                selected
                                    ? FontWeight
                                        .w700
                                    : FontWeight
                                        .w500,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // ==================================================
            // CONTENT
            // ==================================================

            Expanded(
              child:
                  _loading
                      ? const Center(
                          child:
                              CircularProgressIndicator(
                            color:
                                cyan,
                            strokeWidth:
                                2,
                          ),
                        )
                      : _filteredPlaces
                              .isEmpty
                          ? _emptyState()
                          : RefreshIndicator(
                              color:
                                  cyan,
                              backgroundColor:
                                  panel,
                              onRefresh:
                                  _loadSavedPlaces,
                              child:
                                  ListView.builder(
                                padding:
                                    const EdgeInsets
                                        .fromLTRB(
                                  14,
                                  14,
                                  14,
                                  25,
                                ),
                                physics:
                                    const AlwaysScrollableScrollPhysics(
                                  parent:
                                      BouncingScrollPhysics(),
                                ),
                                itemCount:
                                    _filteredPlaces
                                        .length,
                                itemBuilder:
                                    (
                                  context,
                                  index,
                                ) {
                                  return _placeTile(
                                    _filteredPlaces[
                                        index],
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// SAVED PLACE MODEL
// ================================================================

class _SavedPlace {
  final String id;

  final String name;

  final String address;

  final double latitude;

  final double longitude;

  final String category;

  final DateTime? createdAt;

  const _SavedPlace({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.category,
    this.createdAt,
  });

  factory _SavedPlace.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return _SavedPlace(
      id: id,
      name:
          data['name']?.toString() ??
              'Saved place',
      address:
          data['address']?.toString() ??
              '',
      latitude:
          _toDouble(
                data['latitude'],
              ) ??
              0,
      longitude:
          _toDouble(
                data['longitude'],
              ) ??
              0,
      category:
          data['category']?.toString() ??
              'Other',
      createdAt:
          _toDateTime(
        data['createdAt'],
      ),
    );
  }

  static double? _toDouble(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value.toString(),
    );
  }

  static DateTime? _toDateTime(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return DateTime.tryParse(
      value.toString(),
    );
  }
}