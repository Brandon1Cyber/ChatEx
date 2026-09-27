import 'package:flutter/material.dart';

// ============================================================
// CHATTªX — FEED EARNINGS SCREEN
// ============================================================
//
// Advanced creator monetization dashboard.
//
// Revenue sources:
// • Video advertisements
// • Profile advertisements
// • Feed advertisements
// • Creator bonuses
// • Performance rewards
//
// IMPORTANT:
// The values currently displayed are demo values.
// Replace them with Firestore/backend values when the
// ChattªX monetization system is connected.
// ============================================================

class FeedEarningsScreen extends StatefulWidget {
  const FeedEarningsScreen({
    super.key,
  });

  @override
  State<FeedEarningsScreen> createState() =>
      _FeedEarningsScreenState();
}

class _FeedEarningsScreenState
    extends State<FeedEarningsScreen> {
  // ============================================================
  // COLORS — CHATTªX BLUE + PURPLE SYSTEM
  // ============================================================

  static const Color background = Color(0xFF030309);

  static const Color card = Color(0xFF0A0A18);

  static const Color cardDark = Color(0xFF070711);

  static const Color border = Color(0xFF19152D);

  static const Color neonPurple = Color(0xFF7B2FFF);

  static const Color neonBlue = Color(0xFF00C8FF);

  // ============================================================
  // STATE
  // ============================================================

  int _selectedPeriod = 1;

  final List<String> _periods = [
    '7D',
    '30D',
    '90D',
    '1Y',
  ];

  // ============================================================
  // DEMO EARNINGS
  // ============================================================

  double get availableBalance => 1248.50;

  double get pendingBalance => 386.20;

  double get lifetimeEarnings => 8492.75;

  double get currentMonthEarnings => 742.80;

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _buildHeader(),
            ),

            SliverToBoxAdapter(
              child: _buildBalanceCard(),
            ),

            SliverToBoxAdapter(
              child: _buildPeriodSelector(),
            ),

            SliverToBoxAdapter(
              child: _buildAnalyticsCard(),
            ),

            SliverToBoxAdapter(
              child: _buildRevenueSources(),
            ),

            SliverToBoxAdapter(
              child: _buildMonetizationStatus(),
            ),

            SliverToBoxAdapter(
              child: _buildPayoutCard(),
            ),

            SliverToBoxAdapter(
              child: _buildGrowthCard(),
            ),

            SliverToBoxAdapter(
              child: _buildRecentActivity(),
            ),

            SliverToBoxAdapter(
              child: _buildEarningsGoals(),
            ),

            SliverToBoxAdapter(
              child: _buildCreatorTools(),
            ),

            SliverToBoxAdapter(
              child: _buildFooterInfo(),
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: 35),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        18,
        12,
        18,
        18,
      ),
      child: Row(
        children: [
          _buildIconButton(
            icon: Icons.arrow_back_rounded,
            onTap: () {
              Navigator.pop(context);
            },
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) {
                    return const LinearGradient(
                      colors: [
                        neonBlue,
                        neonPurple,
                      ],
                    ).createShader(bounds);
                  },
                  child: const Text(
                    'ChattªX Earnings',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.6,
                    ),
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  'Your creator revenue command center',
                  style: TextStyle(
                    color: neonBlue.withValues(
                      alpha: .45,
                    ),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          _buildIconButton(
            icon: Icons.more_horiz_rounded,
            onTap: _showMoreMenu,
            accent: neonPurple,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BALANCE CARD
  // ============================================================

  Widget _buildBalanceCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: neonBlue.withValues(
              alpha: .28,
            ),
            width: 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: neonBlue.withValues(
                alpha: .07,
              ),
              blurRadius: 30,
              spreadRadius: -5,
            ),
            BoxShadow(
              color: neonPurple.withValues(
                alpha: .055,
              ),
              blurRadius: 42,
              spreadRadius: -8,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _gradientIconContainer(
                  icon: Icons
                      .account_balance_wallet_rounded,
                  size: 43,
                  iconSize: 21,
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Available to withdraw',
                        style: TextStyle(
                          color: neonBlue.withValues(
                            alpha: .45,
                          ),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      ShaderMask(
                        shaderCallback: (bounds) {
                          return const LinearGradient(
                            colors: [
                              neonBlue,
                              neonPurple,
                            ],
                          ).createShader(bounds);
                        },
                        child: const Text(
                          'Creator balance',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                _buildStatusPill(
                  'ACTIVE',
                  accent: neonBlue,
                ),
              ],
            ),

            const SizedBox(height: 25),

            ShaderMask(
              shaderCallback: (bounds) {
                return const LinearGradient(
                  colors: [
                    neonBlue,
                    neonPurple,
                  ],
                ).createShader(bounds);
              },
              child: const Text(
                'R1,248.50',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.5,
                ),
              ),
            ),

            const SizedBox(height: 7),

            Row(
              children: [
                const Icon(
                  Icons.trending_up_rounded,
                  color: neonBlue,
                  size: 15,
                ),
                const SizedBox(width: 5),
                Text(
                  '+18.6% this month',
                  style: TextStyle(
                    color: neonBlue.withValues(
                      alpha: .68,
                    ),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 22),

            Row(
              children: [
                Expanded(
                  child: _buildBalanceMini(
                    title: 'Pending',
                    value:
                        'R${_money(pendingBalance)}',
                    icon: Icons.hourglass_top_rounded,
                    accent: neonPurple,
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: _buildBalanceMini(
                    title: 'Lifetime',
                    value:
                        'R${_money(lifetimeEarnings)}',
                    icon: Icons.auto_graph_rounded,
                    accent: neonBlue,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      neonBlue,
                      neonPurple,
                    ],
                  ),
                  borderRadius:
                      BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: neonBlue.withValues(
                        alpha: .14,
                      ),
                      blurRadius: 18,
                    ),
                    BoxShadow(
                      color: neonPurple.withValues(
                        alpha: .12,
                      ),
                      blurRadius: 24,
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius:
                        BorderRadius.circular(15),
                    onTap: _openPayouts,
                    child: const Center(
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.payments_rounded,
                            color: background,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Manage payouts',
                            style: TextStyle(
                              color: background,
                              fontSize: 13,
                              fontWeight:
                                  FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PERIOD SELECTOR
  // ============================================================

  Widget _buildPeriodSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        22,
        16,
        12,
      ),
      child: Container(
        height: 46,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: cardDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: border,
          ),
        ),
        child: Row(
          children: List.generate(
            _periods.length,
            (index) {
              final selected =
                  _selectedPeriod == index;

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedPeriod = index;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(
                      milliseconds: 180,
                    ),
                    decoration: BoxDecoration(
                      gradient: selected
                          ? const LinearGradient(
                              colors: [
                                neonBlue,
                                neonPurple,
                              ],
                            )
                          : null,
                      color: selected
                          ? null
                          : cardDark,
                      borderRadius:
                          BorderRadius.circular(10),
                      border: selected
                          ? null
                          : Border.all(
                              color: border,
                            ),
                    ),
                    child: Center(
                      child: Text(
                        _periods[index],
                        style: TextStyle(
                          color: selected
                              ? background
                              : neonBlue.withValues(
                                  alpha: .38,
                                ),
                          fontSize: 11,
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ANALYTICS
  // ============================================================

  Widget _buildAnalyticsCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      child: _sectionCard(
        accent: neonBlue,
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              icon: Icons.analytics_rounded,
              title: 'Revenue analytics',
              subtitle:
                  'How your content is performing',
              accent: neonBlue,
            ),

            const SizedBox(height: 22),

            Row(
              children: [
                Expanded(
                  child: _buildMetric(
                    title: 'Earnings',
                    value:
                        'R${_money(currentMonthEarnings)}',
                    change: '+18.6%',
                    accent: neonBlue,
                  ),
                ),
                Expanded(
                  child: _buildMetric(
                    title: 'Ad impressions',
                    value: '91.4K',
                    change: '+24.2%',
                    accent: neonPurple,
                  ),
                ),
                Expanded(
                  child: _buildMetric(
                    title: 'Profile views',
                    value: '124K',
                    change: '+31.8%',
                    accent: neonBlue,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 25),

            Container(
              height: 170,
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(
                vertical: 5,
              ),
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(14),
                color: cardDark,
                border: Border.all(
                  color: border,
                ),
              ),
              child: CustomPaint(
                painter:
                    _EarningsChartPainter(
                  blue: neonBlue,
                  purple: neonPurple,
                  border: border,
                ),
              ),
            ),

            const SizedBox(height: 12),

            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                _chartLabel('01'),
                _chartLabel('07'),
                _chartLabel('14'),
                _chartLabel('21'),
                _chartLabel('30'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // REVENUE SOURCES
  // ============================================================

  Widget _buildRevenueSources() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        10,
        16,
        8,
      ),
      child: _sectionCard(
        accent: neonPurple,
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              icon: Icons.account_tree_rounded,
              title: 'Revenue sources',
              subtitle:
                  'Where your earnings come from',
              accent: neonPurple,
            ),

            const SizedBox(height: 20),

            _buildRevenueRow(
              icon:
                  Icons.play_circle_fill_rounded,
              title: 'Video advertisements',
              subtitle:
                  'Ads shown across your videos',
              amount: 412.35,
              percentage: .56,
              accent: neonBlue,
            ),

            _buildDivider(),

            _buildRevenueRow(
              icon: Icons.person_rounded,
              title: 'Profile advertisements',
              subtitle:
                  'Ads displayed to profile visitors',
              amount: 186.20,
              percentage: .25,
              accent: neonPurple,
            ),

            _buildDivider(),

            _buildRevenueRow(
              icon: Icons.dynamic_feed_rounded,
              title: 'Feed monetization',
              subtitle:
                  'Eligible ads around your content',
              amount: 91.45,
              percentage: .12,
              accent: neonBlue,
            ),

            _buildDivider(),

            _buildRevenueRow(
              icon: Icons.bolt_rounded,
              title: 'Creator performance',
              subtitle:
                  'Platform bonuses and rewards',
              amount: 52.80,
              percentage: .07,
              accent: neonPurple,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // MONETIZATION STATUS
  // ============================================================

  Widget _buildMonetizationStatus() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        10,
        16,
        8,
      ),
      child: _sectionCard(
        accent: neonBlue,
        child: Column(
          children: [
            Row(
              children: [
                _gradientIconContainer(
                  icon: Icons.verified_rounded,
                  size: 45,
                  iconSize: 23,
                ),

                const SizedBox(width: 13),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) {
                          return const LinearGradient(
                            colors: [
                              neonBlue,
                              neonPurple,
                            ],
                          ).createShader(bounds);
                        },
                        child: const Text(
                          'Monetization status',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight:
                                FontWeight.w900,
                          ),
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        'Your account is eligible to earn',
                        style: TextStyle(
                          color: neonBlue.withValues(
                            alpha: .42,
                          ),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),

                _buildStatusPill(
                  'ELIGIBLE',
                  accent: neonPurple,
                ),
              ],
            ),

            const SizedBox(height: 20),

            _buildHealthRow(
              'Account standing',
              'Good',
              accent: neonBlue,
            ),

            _buildHealthRow(
              'Content eligibility',
              'Good',
              accent: neonPurple,
            ),

            _buildHealthRow(
              'Ad eligibility',
              'Active',
              accent: neonBlue,
            ),

            _buildHealthRow(
              'Payout verification',
              'Verified',
              accent: neonPurple,
            ),

            const SizedBox(height: 7),

            TextButton(
              onPressed:
                  _openMonetizationDetails,
              child: ShaderMask(
                shaderCallback: (bounds) {
                  return const LinearGradient(
                    colors: [
                      neonBlue,
                      neonPurple,
                    ],
                  ).createShader(bounds);
                },
                child: const Text(
                  'View monetization requirements',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PAYOUTS
  // ============================================================

  Widget _buildPayoutCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        10,
        16,
        8,
      ),
      child: _sectionCard(
        accent: neonPurple,
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              icon: Icons.account_balance_rounded,
              title: 'Payouts',
              subtitle:
                  'Your next creator payment',
              accent: neonPurple,
            ),

            const SizedBox(height: 20),

            Container(
              padding:
                  const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: cardDark,
                borderRadius:
                    BorderRadius.circular(17),
                border: Border.all(
                  color: neonPurple.withValues(
                    alpha: .17,
                  ),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons
                            .event_available_rounded,
                        color: neonPurple,
                        size: 22,
                      ),

                      const SizedBox(width: 11),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Text(
                              'Estimated next payout',
                              style: TextStyle(
                                color:
                                    neonPurple
                                        .withValues(
                                  alpha: .42,
                                ),
                                fontSize: 9,
                              ),
                            ),
                            const SizedBox(
                              height: 3,
                            ),
                            const Text(
                              '15 September 2026',
                              style: TextStyle(
                                color: neonPurple,
                                fontSize: 13,
                                fontWeight:
                                    FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),

                      ShaderMask(
                        shaderCallback:
                            (bounds) {
                          return const LinearGradient(
                            colors: [
                              neonBlue,
                              neonPurple,
                            ],
                          ).createShader(bounds);
                        },
                        child: Text(
                          'R${_money(availableBalance)}',
                          style:
                              const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight:
                                FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 17),

                  ClipRRect(
                    borderRadius:
                        BorderRadius.circular(8),
                    child:
                        LinearProgressIndicator(
                      minHeight: 7,
                      value: .82,
                      backgroundColor: border,
                      valueColor:
                          const AlwaysStoppedAnimation<
                              Color>(
                        neonPurple,
                      ),
                    ),
                  ),

                  const SizedBox(height: 9),

                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment
                            .spaceBetween,
                    children: [
                      const Text(
                        '82% ready',
                        style: TextStyle(
                          color: neonPurple,
                          fontSize: 9,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Threshold: R1,000',
                        style: TextStyle(
                          color:
                              neonPurple.withValues(
                            alpha: .35,
                          ),
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 13),

            Row(
              children: [
                Expanded(
                  child: _payoutAction(
                    icon:
                        Icons.credit_card_rounded,
                    label: 'Payout method',
                    onTap: _openPayoutMethod,
                    accent: neonBlue,
                  ),
                ),

                const SizedBox(width: 9),

                Expanded(
                  child: _payoutAction(
                    icon:
                        Icons.receipt_long_rounded,
                    label: 'Payout history',
                    onTap: _openPayoutHistory,
                    accent: neonPurple,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CREATOR GROWTH
  // ============================================================

  Widget _buildGrowthCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        10,
        16,
        8,
      ),
      child: _sectionCard(
        accent: neonBlue,
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              icon: Icons.insights_rounded,
              title: 'Creator growth',
              subtitle:
                  'Your audience is driving revenue',
              accent: neonBlue,
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: _growthMetric(
                    icon:
                        Icons.people_alt_rounded,
                    value: '8,492',
                    label: 'Followers',
                    accent: neonBlue,
                  ),
                ),
                Expanded(
                  child: _growthMetric(
                    icon:
                        Icons.visibility_rounded,
                    value: '124K',
                    label: 'Views',
                    accent: neonPurple,
                  ),
                ),
                Expanded(
                  child: _growthMetric(
                    icon:
                        Icons.ads_click_rounded,
                    value: '91.4K',
                    label: 'Ad views',
                    accent: neonBlue,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 22),

            Container(
              padding:
                  const EdgeInsets.all(15),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    neonBlue.withValues(
                      alpha: .045,
                    ),
                    neonPurple.withValues(
                      alpha: .045,
                    ),
                  ],
                ),
                borderRadius:
                    BorderRadius.circular(17),
                border: Border.all(
                  color: neonPurple.withValues(
                    alpha: .14,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.lightbulb_rounded,
                    color: neonPurple,
                    size: 21,
                  ),

                  const SizedBox(width: 11),

                  Expanded(
                    child: Text(
                      'Videos are currently generating the largest share of your ad revenue.',
                      style: TextStyle(
                        color:
                            neonBlue.withValues(
                          alpha: .54,
                        ),
                        fontSize: 10,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // RECENT EARNINGS
  // ============================================================

  Widget _buildRecentActivity() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        10,
        16,
        8,
      ),
      child: _sectionCard(
        accent: neonPurple,
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildSectionHeader(
                    icon: Icons.history_rounded,
                    title: 'Recent earnings',
                    subtitle:
                        'Latest monetization activity',
                    accent: neonPurple,
                  ),
                ),

                TextButton(
                  onPressed:
                      _openAllTransactions,
                  child: const Text(
                    'View all',
                    style: TextStyle(
                      color: neonPurple,
                      fontSize: 10,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            _transactionRow(
              icon:
                  Icons.play_circle_fill_rounded,
              title: 'Video ad revenue',
              subtitle:
                  'Today • 18.2K monetized views',
              amount: '+R24.82',
              accent: neonBlue,
            ),

            _buildDivider(),

            _transactionRow(
              icon: Icons.person_rounded,
              title: 'Profile ad revenue',
              subtitle:
                  'Today • 5.8K profile views',
              amount: '+R11.64',
              accent: neonPurple,
            ),

            _buildDivider(),

            _transactionRow(
              icon: Icons.dynamic_feed_rounded,
              title: 'Feed monetization',
              subtitle:
                  'Yesterday • 12.4K impressions',
              amount: '+R8.91',
              accent: neonBlue,
            ),

            _buildDivider(),

            _transactionRow(
              icon: Icons.bolt_rounded,
              title: 'Creator performance',
              subtitle:
                  '06 Sep • Monthly milestone',
              amount: '+R35.00',
              accent: neonPurple,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EARNINGS GOALS
  // ============================================================

  Widget _buildEarningsGoals() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        10,
        16,
        8,
      ),
      child: _sectionCard(
        accent: neonBlue,
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              icon: Icons.flag_rounded,
              title: 'Earnings goals',
              subtitle:
                  'Build your next revenue milestone',
              accent: neonBlue,
            ),

            const SizedBox(height: 20),

            _goalRow(
              title: 'R10,000 lifetime',
              current: lifetimeEarnings,
              target: 10000,
              accent: neonBlue,
            ),

            const SizedBox(height: 20),

            _goalRow(
              title: '100K monthly profile views',
              current: 74200,
              target: 100000,
              showCurrency: false,
              accent: neonPurple,
            ),

            const SizedBox(height: 20),

            _goalRow(
              title:
                  '100K monthly ad impressions',
              current: 91400,
              target: 100000,
              showCurrency: false,
              accent: neonBlue,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CREATOR TOOLS
  // ============================================================

  Widget _buildCreatorTools() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        10,
        16,
        8,
      ),
      child: _sectionCard(
        accent: neonPurple,
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              icon:
                  Icons.dashboard_customize_rounded,
              title: 'Creator tools',
              subtitle:
                  'Control how you monetize',
              accent: neonPurple,
            ),

            const SizedBox(height: 17),

            _creatorTool(
              icon: Icons.campaign_rounded,
              title: 'Profile advertisements',
              subtitle:
                  'Manage ads displayed to profile visitors',
              trailing: 'ACTIVE',
              accent: neonBlue,
              onTap: () {
                _showInfoSheet(
                  'Profile advertisements',
                  'Manage the monetization settings for eligible advertisements displayed on your profile.',
                );
              },
            ),

            _buildDivider(),

            _creatorTool(
              icon:
                  Icons.play_circle_outline_rounded,
              title: 'Video monetization',
              subtitle:
                  'Manage eligible videos and ad placement',
              trailing: 'ACTIVE',
              accent: neonPurple,
              onTap: () {
                _showInfoSheet(
                  'Video monetization',
                  'Review videos eligible for ChattªX advertising revenue.',
                );
              },
            ),

            _buildDivider(),

            _creatorTool(
              icon: Icons.bar_chart_rounded,
              title: 'Advanced analytics',
              subtitle:
                  'Audience, reach and monetization insights',
              trailing: 'OPEN',
              accent: neonBlue,
              onTap: () {
                _showInfoSheet(
                  'Advanced analytics',
                  'Detailed creator analytics will show audience behaviour, reach, ad performance and revenue.',
                );
              },
            ),

            _buildDivider(),

            _creatorTool(
              icon: Icons.shield_rounded,
              title: 'Earnings integrity',
              subtitle:
                  'Protect your account from invalid activity',
              trailing: 'GOOD',
              accent: neonPurple,
              onTap: () {
                _showInfoSheet(
                  'Earnings integrity',
                  'ChattªX monitors monetized activity for invalid traffic, artificial engagement and other activity that could affect advertiser or creator revenue.',
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // FOOTER
  // ============================================================

  Widget _buildFooterInfo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        25,
        18,
        25,
        0,
      ),
      child: Column(
        children: [
          ShaderMask(
            shaderCallback: (bounds) {
              return const LinearGradient(
                colors: [
                  neonBlue,
                  neonPurple,
                ],
              ).createShader(bounds);
            },
            child: const Icon(
              Icons.shield_rounded,
              color: Colors.white,
              size: 21,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Earnings are calculated from eligible monetized activity. '
            'Invalid traffic, artificial engagement, fraudulent activity '
            'and other prohibited activity may be excluded.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: neonBlue.withValues(
                alpha: .27,
              ),
              fontSize: 9,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // REUSABLE COMPONENTS
  // ============================================================

  Widget _sectionCard({
    required Widget child,
    required Color accent,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: accent.withValues(
            alpha: .14,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(
              alpha: .025,
            ),
            blurRadius: 25,
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accent,
  }) {
    return Row(
      children: [
        Container(
          width: 37,
          height: 37,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                neonBlue.withValues(
                  alpha: .09,
                ),
                neonPurple.withValues(
                  alpha: .09,
                ),
              ],
            ),
            borderRadius:
                BorderRadius.circular(11),
            border: Border.all(
              color: accent.withValues(
                alpha: .18,
              ),
            ),
          ),
          child: Icon(
            icon,
            color: accent,
            size: 19,
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (bounds) {
                  return LinearGradient(
                    colors: [
                      neonBlue,
                      accent,
                    ],
                  ).createShader(bounds);
                },
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ),

              const SizedBox(height: 3),

              Text(
                subtitle,
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style: TextStyle(
                  color: accent.withValues(
                    alpha: .35,
                  ),
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _gradientIconContainer({
    required IconData icon,
    required double size,
    required double iconSize,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            neonBlue.withValues(
              alpha: .11,
            ),
            neonPurple.withValues(
              alpha: .11,
            ),
          ],
        ),
        shape: BoxShape.circle,
        border: Border.all(
          color: neonBlue.withValues(
            alpha: .23,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: neonPurple.withValues(
              alpha: .08,
            ),
            blurRadius: 15,
          ),
        ],
      ),
      child: Icon(
        icon,
        color: neonBlue,
        size: iconSize,
      ),
    );
  }

  Widget _buildBalanceMini({
    required String title,
    required String value,
    required IconData icon,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 11,
      ),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color: accent.withValues(
            alpha: .13,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: accent,
            size: 17,
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: accent.withValues(
                      alpha: .34,
                    ),
                    fontSize: 9,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  value,
                  style: TextStyle(
                    color: accent,
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetric({
    required String title,
    required String value,
    required String change,
    required Color accent,
  }) {
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: accent.withValues(
              alpha: .34,
            ),
            fontSize: 8,
          ),
        ),

        const SizedBox(height: 6),

        FittedBox(
          child: Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 14,
              fontWeight:
                  FontWeight.w900,
            ),
          ),
        ),

        const SizedBox(height: 4),

        Text(
          change,
          style: TextStyle(
            color: accent.withValues(
              alpha: .70,
            ),
            fontSize: 8,
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildRevenueRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required double amount,
    required double percentage,
    required Color accent,
  }) {
    return Row(
      children: [
        Container(
          width: 39,
          height: 39,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                neonBlue.withValues(
                  alpha: .065,
                ),
                neonPurple.withValues(
                  alpha: .065,
                ),
              ],
            ),
            borderRadius:
                BorderRadius.circular(11),
            border: Border.all(
              color: accent.withValues(
                alpha: .12,
              ),
            ),
          ),
          child: Icon(
            icon,
            color: accent,
            size: 19,
          ),
        ),

        const SizedBox(width: 11),

        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: accent,
                  fontSize: 12,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),

              const SizedBox(height: 3),

              Text(
                subtitle,
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style: TextStyle(
                  color: accent.withValues(
                    alpha: .34,
                  ),
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),

        Column(
          crossAxisAlignment:
              CrossAxisAlignment.end,
          children: [
            Text(
              '+R${_money(amount)}',
              style: TextStyle(
                color: accent,
                fontSize: 12,
                fontWeight:
                    FontWeight.w900,
              ),
            ),

            const SizedBox(height: 3),

            Text(
              '${(percentage * 100).toInt()}%',
              style: TextStyle(
                color: accent.withValues(
                  alpha: .65,
                ),
                fontSize: 9,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHealthRow(
    String title,
    String value, {
    required Color accent,
  }) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 13,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: accent.withValues(
                  alpha: .50,
                ),
                fontSize: 10,
              ),
            ),
          ),

          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 10,
              fontWeight:
                  FontWeight.w800,
            ),
          ),

          const SizedBox(width: 8),

          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent,
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(
                    alpha: .35,
                  ),
                  blurRadius: 7,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _transactionRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required String amount,
    required Color accent,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 10,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withValues(
                alpha: .065,
              ),
              borderRadius:
                  BorderRadius.circular(11),
              border: Border.all(
                color: accent.withValues(
                  alpha: .10,
                ),
              ),
            ),
            child: Icon(
              icon,
              color: accent,
              size: 18,
            ),
          ),

          const SizedBox(width: 11),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: accent,
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  subtitle,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: TextStyle(
                    color: accent.withValues(
                      alpha: .30,
                    ),
                    fontSize: 8,
                  ),
                ),
              ],
            ),
          ),

          Text(
            amount,
            style: TextStyle(
              color: accent,
              fontSize: 11,
              fontWeight:
                  FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _goalRow({
    required String title,
    required double current,
    required double target,
    required Color accent,
    bool showCurrency = true,
  }) {
    final progress =
        (current / target).clamp(0.0, 1.0);

    final currentText = showCurrency
        ? 'R${_money(current)}'
        : _compactNumber(current);

    final targetText = showCurrency
        ? 'R${_money(target)}'
        : _compactNumber(target);

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: accent,
                  fontSize: 11,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ),

            Text(
              '$currentText / $targetText',
              style: TextStyle(
                color: accent.withValues(
                  alpha: .42,
                ),
                fontSize: 9,
              ),
            ),
          ],
        ),

        const SizedBox(height: 9),

        ClipRRect(
          borderRadius:
              BorderRadius.circular(8),
          child: Stack(
            children: [
              Container(
                height: 6,
                width: double.infinity,
                color: border,
              ),

              FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        neonBlue,
                        accent,
                      ],
                    ),
                    borderRadius:
                        BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _growthMetric({
    required IconData icon,
    required String value,
    required String label,
    required Color accent,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color: accent,
          size: 19,
        ),

        const SizedBox(height: 7),

        Text(
          value,
          style: TextStyle(
            color: accent,
            fontSize: 14,
            fontWeight:
                FontWeight.w900,
          ),
        ),

        const SizedBox(height: 3),

        Text(
          label,
          style: TextStyle(
            color: accent.withValues(
              alpha: .32,
            ),
            fontSize: 8,
          ),
        ),
      ],
    );
  }

  Widget _creatorTool({
    required IconData icon,
    required String title,
    required String subtitle,
    required String trailing,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(14),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(
            vertical: 10,
          ),
          child: Row(
            children: [
              Container(
                width: 39,
                height: 39,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      neonBlue.withValues(
                        alpha: .06,
                      ),
                      neonPurple.withValues(
                        alpha: .07,
                      ),
                    ],
                  ),
                  borderRadius:
                      BorderRadius.circular(11),
                  border: Border.all(
                    color: accent.withValues(
                      alpha: .12,
                    ),
                  ),
                ),
                child: Icon(
                  icon,
                  color: accent,
                  size: 19,
                ),
              ),

              const SizedBox(width: 11),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: accent,
                        fontSize: 11,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: TextStyle(
                        color:
                            accent.withValues(
                          alpha: .32,
                        ),
                        fontSize: 8,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Text(
                trailing,
                style: TextStyle(
                  color: accent,
                  fontSize: 8,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),

              const SizedBox(width: 4),

              Icon(
                Icons.chevron_right_rounded,
                color: accent.withValues(
                  alpha: .35,
                ),
                size: 17,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _payoutAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color accent,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius:
            BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(
            vertical: 13,
            horizontal: 8,
          ),
          decoration: BoxDecoration(
            color: cardDark,
            borderRadius:
                BorderRadius.circular(14),
            border: Border.all(
              color: accent.withValues(
                alpha: .13,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: accent,
                size: 16,
              ),

              const SizedBox(width: 6),

              Flexible(
                child: Text(
                  label,
                  overflow:
                      TextOverflow.ellipsis,
                  style: TextStyle(
                    color: accent,
                    fontSize: 9,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPill(
    String text, {
    required Color accent,
  }) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            neonBlue.withValues(
              alpha: .055,
            ),
            neonPurple.withValues(
              alpha: .055,
            ),
          ],
        ),
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: accent.withValues(
            alpha: .25,
          ),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: accent,
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: .5,
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onTap,
    Color accent = neonBlue,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius:
            BorderRadius.circular(13),
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: card,
            borderRadius:
                BorderRadius.circular(13),
            border: Border.all(
              color: accent.withValues(
                alpha: .14,
              ),
            ),
          ),
          child: Icon(
            icon,
            color: accent.withValues(
              alpha: .80,
            ),
            size: 19,
          ),
        ),
      ),
    );
  }

  Widget _chartLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: neonBlue.withValues(
          alpha: .25,
        ),
        fontSize: 8,
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 5,
      ),
      child: Divider(
        height: 1,
        thickness: .5,
        color: border,
      ),
    );
  }

  // ============================================================
  // ACTIONS
  // ============================================================

  void _openPayouts() {
    _showInfoSheet(
      'Payouts',
      'Manage your available earnings, payout schedule and verified payment destination.',
    );
  }

  void _openPayoutMethod() {
    _showInfoSheet(
      'Payout method',
      'Connect and manage the verified payout destination for your ChattªX earnings.',
    );
  }

  void _openPayoutHistory() {
    _showInfoSheet(
      'Payout history',
      'View completed, pending and failed creator payouts.',
    );
  }

  void _openAllTransactions() {
    _showInfoSheet(
      'Earnings history',
      'Your complete monetization ledger will appear here.',
    );
  }

  void _openMonetizationDetails() {
    _showInfoSheet(
      'Monetization eligibility',
      'Review the requirements and account checks used to keep your ChattªX account eligible for creator earnings.',
    );
  }

  // ============================================================
  // MORE MENU
  // ============================================================

  void _showMoreMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: card,
      shape:
          const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.all(20),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                _bottomAction(
                  Icons.download_rounded,
                  'Download earnings report',
                  neonBlue,
                ),
                _bottomAction(
                  Icons.settings_rounded,
                  'Earnings settings',
                  neonPurple,
                ),
                _bottomAction(
                  Icons.help_outline_rounded,
                  'Earnings help',
                  neonBlue,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _bottomAction(
    IconData icon,
    String title,
    Color accent,
  ) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(
        vertical: 2,
      ),
      leading: Icon(
        icon,
        color: accent,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: accent,
          fontWeight:
              FontWeight.w700,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
      },
    );
  }

  // ============================================================
  // INFO SHEET
  // ============================================================

  void _showInfoSheet(
    String title,
    String message,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: card,
      shape:
          const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.all(24),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration:
                      BoxDecoration(
                    gradient:
                        const LinearGradient(
                      colors: [
                        neonBlue,
                        neonPurple,
                      ],
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      10,
                    ),
                  ),
                ),

                const SizedBox(
                  height: 22,
                ),

                ShaderMask(
                  shaderCallback: (bounds) {
                    return const LinearGradient(
                      colors: [
                        neonBlue,
                        neonPurple,
                      ],
                    ).createShader(bounds);
                  },
                  child: Text(
                    title,
                    textAlign:
                        TextAlign.center,
                    style:
                        const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                ),

                const SizedBox(
                  height: 10,
                ),

                Text(
                  message,
                  textAlign:
                      TextAlign.center,
                  style: TextStyle(
                    color:
                        neonBlue.withValues(
                      alpha: .45,
                    ),
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),

                const SizedBox(
                  height: 20,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // FORMATTERS
  // ============================================================

  String _money(double value) {
    return value.toStringAsFixed(2);
  }

  String _compactNumber(
    double value,
  ) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }

    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }

    return value.toStringAsFixed(0);
  }
}

// ============================================================
// CHATTªX BLUE + PURPLE EARNINGS CHART
// ============================================================

class _EarningsChartPainter
    extends CustomPainter {
  final Color blue;
  final Color purple;
  final Color border;

  _EarningsChartPainter({
    required this.blue,
    required this.purple,
    required this.border,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final chartWidth = size.width;
    final chartHeight = size.height;

    // ==========================================================
    // GRID
    // ==========================================================

    final gridPaint = Paint()
      ..color = border.withValues(
        alpha: .65,
      )
      ..strokeWidth = .7;

    for (int i = 0; i < 5; i++) {
      final y =
          (chartHeight - 15) *
              (i / 4);

      canvas.drawLine(
        Offset(0, y),
        Offset(chartWidth, y),
        gridPaint,
      );
    }

    // ==========================================================
    // DEMO DATA
    // ==========================================================

    final values = [
      .19,
      .26,
      .23,
      .34,
      .31,
      .48,
      .44,
      .52,
      .47,
      .61,
      .58,
      .69,
      .64,
      .76,
      .70,
      .82,
      .74,
      .88,
      .81,
      .93,
      .86,
      .97,
      .91,
      .96,
      .89,
      .98,
      .94,
      1.0,
      .95,
      1.0,
    ];

    final path = Path();

    for (int i = 0;
        i < values.length;
        i++) {
      final x =
          chartWidth *
              (i /
                  (values.length - 1));

      final y =
          chartHeight -
              15 -
              (values[i] *
                  (chartHeight - 30));

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        final previousX =
            chartWidth *
                ((i - 1) /
                    (values.length - 1));

        final previousY =
            chartHeight -
                15 -
                (values[i - 1] *
                    (chartHeight - 30));

        final controlX =
            (previousX + x) / 2;

        path.cubicTo(
          controlX,
          previousY,
          controlX,
          y,
          x,
          y,
        );
      }
    }

    // ==========================================================
    // AREA
    // ==========================================================

    final areaPath =
        Path.from(path)
          ..lineTo(
            chartWidth,
            chartHeight,
          )
          ..lineTo(
            0,
            chartHeight,
          )
          ..close();

    final areaPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          blue.withValues(
            alpha: .13,
          ),
          purple.withValues(
            alpha: .075,
          ),
          purple.withValues(
            alpha: .01,
          ),
        ],
      ).createShader(
        Rect.fromLTWH(
          0,
          0,
          chartWidth,
          chartHeight,
        ),
      );

    canvas.drawPath(
      areaPath,
      areaPaint,
    );

    // ==========================================================
    // LINE GLOW
    // ==========================================================

    final glowPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          blue.withValues(
            alpha: .28,
          ),
          purple.withValues(
            alpha: .28,
          ),
        ],
      ).createShader(
        Rect.fromLTWH(
          0,
          0,
          chartWidth,
          chartHeight,
        ),
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(
        BlurStyle.normal,
        7,
      );

    canvas.drawPath(
      path,
      glowPaint,
    );

    // ==========================================================
    // MAIN LINE
    // ==========================================================

    final linePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          blue,
          purple,
        ],
      ).createShader(
        Rect.fromLTWH(
          0,
          0,
          chartWidth,
          chartHeight,
        ),
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(
      path,
      linePaint,
    );

    // ==========================================================
    // CURRENT POINT
    // ==========================================================

    final lastX = chartWidth;

    final lastY =
        chartHeight -
            15 -
            (values.last *
                (chartHeight - 30));

    final pointGlow = Paint()
      ..color = purple.withValues(
        alpha: .22,
      )
      ..maskFilter = const MaskFilter.blur(
        BlurStyle.normal,
        10,
      );

    canvas.drawCircle(
      Offset(lastX, lastY),
      8,
      pointGlow,
    );

    final pointPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          _FeedEarningsScreenState.neonBlue,
          _FeedEarningsScreenState.neonPurple,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(
            lastX,
            lastY,
          ),
          radius: 4,
        ),
      );

    canvas.drawCircle(
      Offset(lastX, lastY),
      3.5,
      pointPaint,
    );
  }

  @override
  bool shouldRepaint(
    covariant _EarningsChartPainter oldDelegate,
  ) {
    return oldDelegate.blue != blue ||
        oldDelegate.purple != purple ||
        oldDelegate.border != border;
  }
}