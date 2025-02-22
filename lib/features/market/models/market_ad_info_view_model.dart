import 'package:agoradesk/core/api/api_errors.dart';
import 'package:agoradesk/core/events.dart';
import 'package:agoradesk/core/extensions/capitalized_first_letter.dart';
import 'package:agoradesk/core/extensions/even_rounding.dart';
import 'package:agoradesk/core/theme/theme.dart';
import 'package:agoradesk/core/utils/error_parse_mixin.dart';
import 'package:agoradesk/core/utils/string_mixin.dart';
import 'package:agoradesk/core/utils/validator_mixin.dart';
import 'package:agoradesk/core/widgets/branded/button_filled_p80.dart';
import 'package:agoradesk/features/ads/data/models/ad_model.dart';
import 'package:agoradesk/features/ads/data/models/asset.dart';
import 'package:agoradesk/features/ads/data/models/network_fees.dart';
import 'package:agoradesk/features/ads/data/models/trade_type.dart';
import 'package:agoradesk/features/ads/data/repositories/ads_repository.dart';
import 'package:agoradesk/features/auth/data/services/auth_service.dart';
import 'package:agoradesk/features/trades/data/repository/trade_repository.dart';
import 'package:agoradesk/features/wallet/data/models/btc_fee_model.dart';
import 'package:agoradesk/features/wallet/data/services/wallet_service.dart';
import 'package:agoradesk/router.gr.dart';
import 'package:auto_route/auto_route.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/cupertino.dart';
import 'package:vm/vm.dart';

const _kDebounceTag = '_kDebounceTag';

class MarketAdInfoViewModel extends ViewModel with ValidatorMixin, ErrorParseMixin, StringMixin {
  MarketAdInfoViewModel({
    required TradeRepository tradeRepository,
    required WalletService walletService,
    required AuthService authService,
    required AdsRepository adsRepository,
    this.adModel,
    this.adId,
  })  : _tradeRepository = tradeRepository,
        _authService = authService,
        _walletService = walletService,
        _adsRepository = adsRepository;

  final TradeRepository _tradeRepository;
  final AuthService _authService;
  final WalletService _walletService;
  final AdsRepository _adsRepository;
  final AdModel? adModel;
  final String? adId;

  final ctrlReceive = TextEditingController();
  final ctrlSettlementAddress = TextEditingController();
  final ctrlPay = TextEditingController();

  late Asset _asset;
  final List<AdModel> ads = [];
  final List<AdModel> filteredAds = [];
  double _receive = 0;
  String? receiveError;
  double _pay = 0;
  double _balanceBtc = 0;
  double _balanceXmr = 0;
  String? payError;
  AdModel? ad;
  late bool isGuestMode;

  TradeType? _tradeType = TradeType.ONLINE_BUY;

  List<String> tradeTypeMenu = [];
  List<String> assetMenu = [];

  bool _loadingAds = true;
  // bool _initialized = false;
  bool _calculating = false;
  bool _startingTrade = false;
  bool _loadingFees = false;
  bool initialLoadingAd = true;
  bool _loadingBalance = false;
  BtcFeesEnum _btcFeesEnum = BtcFeesEnum.MEDIUM;
  bool readyToDeal = false;
  bool isWalletValid = false;
  BtcFeesModel? btcFees;
  String address = '';

  late final bool isSell;
  late final bool isAdOwner;

  bool get isXmr => ad?.asset == Asset.XMR;

  bool get loadingFees => _loadingFees;

  set loadingFees(bool v) => updateWith(loadingFees: v);

  bool get loadingBalance => _loadingBalance;

  set loadingBalance(bool v) => updateWith(loadingBalance: v);

  BtcFeesEnum get btcFeesEnum => _btcFeesEnum;

  set btcFeesEnum(BtcFeesEnum v) => updateWith(btcFeesEnum: v);

  bool get startingTrade => _startingTrade;

  set startingTrade(bool v) => updateWith(startingTrade: v);

  bool get loadingAds => _loadingAds;

  set loadingAds(bool v) => updateWith(loadingAds: v);

  Asset? get asset => _asset;

  set asset(Asset? v) => updateWith(asset: v);

  TradeType? get tradeType => _tradeType;

  set tradeType(TradeType? v) => updateWith(tradeType: v);

  @override
  void init() {
    //todo - refactor me (maybe with AutoRoute)
    isGuestMode = _authService.authState == AuthState.guest || _authService.authState == AuthState.initial;
    _authService.onAuthStateChange.listen((e) {
      isGuestMode = e == AuthState.guest || _authService.authState == AuthState.initial;
      notifyListeners();
    });
    _initMenus();
    _textFieldsListeners();
    _initialLoading();
    super.init();
  }

  void _initialLoading() async {
    initialLoadingAd = true;
    notifyListeners();
    if (adModel == null) {
      final res = await _adsRepository.getAd(adId!);
      if (res.isRight) {
        ad = res.right;
        isSell = sellPublicTypes.contains(ad!.tradeType);
        isAdOwner = ad!.profile == null;
        _asset = ad!.asset!;
        if (!isGuestMode) {
          await _getWalletsBalance();
        }
        initialLoadingAd = false;
      } else {
        handleApiError(res.left, context);
      }
    } else {
      ad = adModel;
      isSell = sellPublicTypes.contains(ad!.tradeType);
      isAdOwner = ad!.profile == null;
      _asset = ad!.asset!;
      if (!isGuestMode) {
        await _getWalletsBalance();
      }
      initialLoadingAd = false;
    }
    notifyListeners();
  }

  void _initMenus() {
    tradeTypeMenu.addAll(TradeType.values.map((e) => e.translatedTitle(context).capitalize()).toList());
    assetMenu.addAll(Asset.values.map((e) => e.key()));
  }

  void _textFieldsListeners() {
    ctrlReceive.addListener(_processReceive);
    ctrlPay.addListener(_processPay);
    ctrlSettlementAddress.addListener(_processSettlementAddress);
  }

  void _processSettlementAddress() {
    if (!startingTrade) {
      EasyDebounce.debounce(
        _kDebounceTag,
        const Duration(milliseconds: 500),
        handleWalletAddress,
      );
    }
  }

  void handleWalletAddress() async {
    address = ctrlSettlementAddress.text;
    isWalletValid = validateWalletAddress(asset!, address);
    if (isWalletValid && asset == Asset.BTC) {
      await getBtcFees(address: address);
    }
    notifyListeners();
  }

  Widget actionButton(BuildContext context) {
    if (isGuestMode) {
      return ButtonFilledP80(
        onPressed: () => AutoRouter.of(context).push(LoginRoute(displaySkip: false)),
        title: context.intl.log_in_to_start_trading,
      );
    }

    if (isAdOwner) {
      return ButtonFilledP80(
        onPressed: () => context.pushRoute(AdEditRoute(ad: ad!)),
        title: context.intl.ad8722Sbpage250Sbedit8722Sbad8722Sbbtn,
      );
    }

    return ButtonFilledP80(
      onPressed: () => context.pushRoute(InitiateTradeRoute(model: this)),
      title: sellPublicTypes.contains(ad!.tradeType)
          ? context.intl.ad8722Sblisting8722Sbtable250Sbsell8722Sbbtn
          : context.intl.ad8722Sblisting8722Sbtable250Sbbuy8722Sbbtn,
    );
  }

  Future<void> _getWalletsBalance() async {
    loadingBalance = true;
    final resBtc = await _walletService.getBalance(Asset.BTC);
    final resXmr = await _walletService.getBalance(Asset.XMR);
    loadingBalance = false;
    if (resBtc.isRight && resXmr.isRight) {
      _balanceBtc = resBtc.right.balance;
      _balanceXmr = resXmr.right.balance;
    } else {
      handleApiError(resBtc.left, context);
    }
  }

  Future getBtcFees({String? address}) async {
    // reloadPaymentMethods = true;
    loadingFees = true;
    final res = await _walletService.getBtcFees(address);
    loadingFees = false;
    if (res.isRight) {
      btcFees = res.right;
    } else {
      if (res.left.message.containsKey('error_code')) {
        final errorMessage = ApiErrors.translatedCodeError(res.left.message['error_code'], context);
        debugPrint('[getBtcFees error message] $errorMessage');
      }
      debugPrint('[getBtcFees error] ${res.left.message}');
      return null;
    }
  }

  void _processReceive() {
    if (!_calculating) {
      _calculating = true;
      receiveError = null;
      if (ctrlReceive.text.isEmpty) {
        ctrlPay.text = '';
      } else {
        try {
          _receive = double.parse(ctrlReceive.text);
          final int digitsToRound = getBankersDigits(asset!.name);
          _pay = (_receive / (double.tryParse(ad!.tempPrice!) ?? 0)).bankerRound(digitsToRound).toDouble();
          ctrlPay.text = _pay.toString();
          _checkReceiveQuantity();
        } catch (e) {
          receiveError = context.intl.error_only_numbers_are_possible;
        }
      }
      notifyListeners();
      _calculating = false;
    }
  }

  void _processPay() {
    if (!_calculating) {
      if (ctrlPay.text.isEmpty) {
        ctrlReceive.text = '';
      } else {
        _calculating = true;
        payError = null;
        try {
          _pay = double.parse(ctrlPay.text);
          final int digitsToRound = getBankersDigits(ad?.currency ?? '');
          _receive = ((double.tryParse(ad!.tempPrice!) ?? 0) * _pay).bankerRound(digitsToRound).toDouble();
          ctrlReceive.text = _receive.toString();
          _checkReceiveQuantity();
          _checkPayQuantity();
        } catch (e) {
          payError = context.intl.error_only_numbers_are_possible;
        }
        notifyListeners();
        _calculating = false;
      }
    }
  }

  void _checkReceiveQuantity() {
    if (_receive < (ad!.minAmount ?? 0)) {
      receiveError = context.intl.must_be_at_least((ad!.minAmount ?? 0).toString(), ad!.currency);
      readyToDeal = false;
    } else if (ad!.maxAmountAvailable != null && _receive > ad!.maxAmountAvailable!) {
      receiveError = context.intl.must_be_less((ad!.maxAmountAvailable!).toString(), ad!.currency);
      readyToDeal = false;
    } else if (ad!.maxAmountAvailable == null && ad!.maxAmount != null && _receive > ad!.maxAmount!) {
      receiveError = context.intl.must_be_less((ad!.maxAmount!).toString(), ad!.currency);
      readyToDeal = false;
    } else {
      readyToDeal = true;
      receiveError = null;
    }
  }

  void _checkPayQuantity() {
    if (!ad!.tradeType.isSell()) {
      if (_pay > (ad!.asset == Asset.BTC ? _balanceBtc : _balanceXmr)) {
        payError = context.intl.error250Sbwithdraw250Sb7438Sb77;
        readyToDeal = false;
      } else {
        readyToDeal = true;
        payError = null;
      }
    }
  }

  void setTradeType(String? selected) {
    final index = tradeTypeMenu.indexWhere((e) => e == selected);
    if (index == 0 || index == -1) {
      tradeType = null;
    } else {
      tradeType = TradeType.values[index - 1];
    }
    filterAds();
    notifyListeners();
  }

  void setAsset(String? selected) {
    final index = assetMenu.indexWhere((e) => e == selected);
    if (index == 0 || index == -1) {
      asset = null;
    } else {
      asset = Asset.values[index - 1];
    }
    filterAds();
    notifyListeners();
  }

  void filterAds() {
    filteredAds.clear();
    for (final ad in ads) {
      if (tradeType == null) {
        filteredAds.add(ad);
      } else if (ad.tradeType == tradeType) {
        filteredAds.add(ad);
      }
      if (asset != null) {
        filteredAds.removeWhere((e) => e.asset != asset);
      }
    }
  }

  Future startTrade(BuildContext context) async {
    if (!startingTrade) {
      // if (!isSell || (isSell && checkWalletAddressCorrect))
      startingTrade = true;
      final res = await _tradeRepository.startTrade(
        adId: ad!.id!,
        amount: _receive.toString(),
        address: address,
        feeLevel: _btcFeesEnum.name,
        asset: asset!,
        isSell: isSell,
      );
      startingTrade = false;
      if (res.isRight) {
        eventBus.fire(FlashEvent.success(context.intl.app_trade_created));
        context.router.popUntilRoot();
        context.router.push(TradeRoute(tradeId: res.right));
      } else {
        handleApiError(res.left, context);
      }
      notifyListeners();
    }
  }

  String howMuchSign(BuildContext context) {
    return context.intl.app_buy_sell(ad!.tradeType.isSell()
        ? context.intl.ad8722Sbpage250Sbhow8722Sbmuch8722Sbdo8722Sbyou8722Sbwish8722Sbto8722Sbbuy
        : context.intl.ad8722Sbpage250Sbhow8722Sbmuch8722Sbdo8722Sbyou8722Sbwish8722Sbto8722Sbsell);
  }

  void pasteAllAvailableBalance() {
    ctrlPay.text = isXmr ? _balanceXmr.toString() : _balanceBtc.toString();
  }

  void updateWith({
    Asset? asset,
    TradeType? tradeType,
    BtcFeesEnum? btcFeesEnum,
    bool? loadingAds,
    bool? loadingBalance,
    bool? loadingSettings,
    bool? loadingFees,
    bool? startingTrade,
  }) async {
    bool reloadAds = false;
    _loadingAds = loadingAds ?? _loadingAds;
    _loadingBalance = loadingBalance ?? _loadingBalance;
    _loadingFees = loadingFees ?? _loadingFees;
    _startingTrade = startingTrade ?? _startingTrade;
    _btcFeesEnum = btcFeesEnum ?? _btcFeesEnum;
    if ((_asset != asset && asset != null || _tradeType != tradeType && tradeType != null) && !_loadingAds) {
      reloadAds = true;
    }
    _asset = asset ?? _asset;
    _tradeType = tradeType ?? _tradeType;

    if (reloadAds) {
      reloadAds = false;
      // _getAds();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    ctrlReceive.dispose();
    ctrlPay.dispose();
    EasyDebounce.cancel(_kDebounceTag);
    super.dispose();
  }
}
