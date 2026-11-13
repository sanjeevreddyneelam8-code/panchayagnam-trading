import 'package:easy_trade_web/service/ip_service.dart';
import 'package:easy_trade_web/service/individual_drop_down_service.dart';
import 'package:easy_trade_web/service/theme_mode_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'app_route/app_route.dart';
import 'bloc/add_demat_account/add_demat_bloc.dart';
import 'bloc/admin_accounts_bloc/delete_admin_account_bloc/demote_admin_bloc.dart';
import 'bloc/admin_accounts_bloc/fetch_py_users_bloc.dart';
import 'bloc/approve_user_to_admin_bloc/approve_users_bloc.dart';
import 'bloc/auth_bloc/authbloc.dart';
import 'bloc/broker_fetch_balance_bloc/fetch_account_balance_bloc.dart';
import 'bloc/broker_o_auth_dilogue_bloc/broker_o_auth_bloc.dart';
import 'bloc/dashboard_count_bloc/count_bloc.dart';
import 'bloc/fetch_demat_accounts/fetch_demat_bloc.dart';
import 'bloc/fetch_user_demat_bloc/fetch_user_demat_bloc.dart';
import 'bloc/group_order_bloc/group_order_bloc.dart';
import 'bloc/group_order_buy_sell_bloc/group_order_buy_sell_bloc.dart';
import 'bloc/group_positions_bloc/group_positions_bloc.dart';
import 'bloc/hot_stock_bloc/hot_stock_block.dart';
import 'bloc/individual_bloc/individual_execution_bloc.dart';
import 'bloc/individual_dropdown_bloc/individual_drop_down_bloc.dart';
import 'bloc/ip_based_bloc/ip_bloc.dart';
import 'bloc/subscreption_status_bloc/subscreption_status_bloc.dart';
import 'bloc/subsecrption_bloc/subscription_bloc.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(create: (_) => AuthBloc()),
        BlocProvider<GroupPositionsBloc>(create: (_) => GroupPositionsBloc()),
        BlocProvider<FetchDematBloc>(create: (_) => FetchDematBloc()),
        BlocProvider<AddDematBloc>(create: (_) => AddDematBloc()),
        BlocProvider<IndividualExecutionBloc>(
          create: (_) => IndividualExecutionBloc.create(),
        ),
        BlocProvider<ApproveUsersBloc>(create: (_) => ApproveUsersBloc()),
        BlocProvider<SubscriptionBloc>(create: (_) => SubscriptionBloc()),
        BlocProvider<FetchAccountBalanceBloc>(
          create: (_) => FetchAccountBalanceBloc(),
        ),
        BlocProvider<SubscriptionStatusBloc>(
          create: (_) => SubscriptionStatusBloc(),
        ),
        BlocProvider<FetchPyUsersBloc>(create: (_) => FetchPyUsersBloc()),
        BlocProvider<BrokerOAuthBloc>(create: (_) => BrokerOAuthBloc()),
        BlocProvider<FetchUserDematBloc>(create: (_) => FetchUserDematBloc()),
        BlocProvider<TradeGroupBloc>(create: (_) => TradeGroupBloc()),
        BlocProvider<HotStockBloc>(create: (_) => HotStockBloc()),
        BlocProvider<DashboardStatsBloc>(create: (_) => DashboardStatsBloc()),
        BlocProvider<GroupOrderBloc>(create: (_) => GroupOrderBloc()),
        BlocProvider<DemoteAdminBloc>(create: (_) => DemoteAdminBloc()),
        BlocProvider<IpBloc>(create: (_) => IpBloc(repository: IpRepository())),
        BlocProvider<BrokerBloc>(
          create: (_) => BrokerBloc(brokerService: BrokerService()),
        ),
      ],
      child: ValueListenableBuilder<bool>(
        valueListenable: ThemeModeService.isDarkModeNotifier,
        builder: (context, isDark, _) {
          return MaterialApp.router(
            title: 'PANCHAYAGNAM',
            debugShowCheckedModeBanner: false,
            themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
            theme: ThemeData(
              primarySwatch: Colors.green,
              primaryColor: const Color(0xFF059669),
              scaffoldBackgroundColor: const Color(0xFFF8FAFC),
              fontFamily: 'Inter',
              brightness: Brightness.light,
              cardColor: Colors.white,
              dividerColor: const Color(0xFFE2E8F0),
            ),
            darkTheme: ThemeData.dark().copyWith(
              primaryColor: const Color(0xFF10B981),
              scaffoldBackgroundColor: const Color(0xFF081214),
              cardColor: const Color(0xFF0F1E22),
              canvasColor: const Color(0xFF0F1E22),
              dialogBackgroundColor: const Color(0xFF0F1E22),
              dividerColor: const Color(0xFF162E34),
              colorScheme: const ColorScheme.dark(
                primary: Color(0xFF10B981),
                secondary: Color(0xFF34D399),
                surface: Color(0xFF0F1E22),
              ),
            ),
            routerConfig: appRouter,
          );
        },
      ),
    );
  }
}
