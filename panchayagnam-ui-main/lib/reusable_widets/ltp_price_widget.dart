import 'package:flutter/material.dart';
import '../../../../constants/colors.dart';
import '../../../../constants/text_size_constants.dart';
import '../../../../models/execution_models.dart';

class LtpPriceWidget extends StatelessWidget {
  final ScripInfo? scrip;
  final LtpData? ltpData;
  final bool isLoading;

  const LtpPriceWidget({
    Key? key,
    required this.scrip,
    required this.ltpData,
    required this.isLoading,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.candlestick_chart_outlined,
                  color: AppColors.primary, size: 15),
              const SizedBox(width: 6),
              Text(
                'Live Price',
                style: TextStyle(
                  fontSize: TextSizeConstants.small,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              if (scrip != null)
                _ExchangeBadge(exchange: scrip!.exchange),
            ],
          ),
          SizedBox(height: 12),
          if (isLoading)
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2),
              ),
            )
          else if (ltpData == null)
            _EmptyState(hasSelection: scrip != null)
          else
            _PriceContent(scrip: scrip!, data: ltpData!),
        ],
      ),
    );
  }
}

class _ExchangeBadge extends StatelessWidget {
  final String exchange;
  const _ExchangeBadge({required this.exchange});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primaryBg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        exchange,
        style: TextStyle(
          fontSize: TextSizeConstants.xSmall,
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasSelection;
  const _EmptyState({required this.hasSelection});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(
            hasSelection
                ? Icons.hourglass_empty_rounded
                : Icons.search_rounded,
            color: AppColors.textHint,
            size: 28,
          ),
          const SizedBox(height: 8),
          Text(
            hasSelection
                ? 'Fetching live price...'
                : 'Search and select a stock',
            style: TextStyle(
              fontSize: TextSizeConstants.small,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceContent extends StatelessWidget {
  final ScripInfo scrip;
  final LtpData data;

  const _PriceContent({required this.scrip, required this.data});

  @override
  Widget build(BuildContext context) {
    final isPositive = data.isPositive;
    final changeColor =
        isPositive ? AppColors.success : AppColors.error;
    final changeBg =
        isPositive ? AppColors.successBg : AppColors.errorBg;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₹${data.ltp.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: changeBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(
                    isPositive
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    size: 11,
                    color: changeColor,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${isPositive ? '+' : ''}${data.changeAbs.toStringAsFixed(2)} (${data.changePercent.toStringAsFixed(2)}%)',
                    style: TextStyle(
                      fontSize: TextSizeConstants.xSmall,
                      color: changeColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _StatCell(label: 'Open', value: data.open),
            _Divider(),
            _StatCell(label: 'High', value: data.high, isHigh: true),
            _Divider(),
            _StatCell(label: 'Low', value: data.low, isLow: true),
            _Divider(),
            _StatCell(label: 'Prev Close', value: data.close),
          ],
        ),
      ],
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final double value;
  final bool isHigh;
  final bool isLow;

  const _StatCell({
    required this.label,
    required this.value,
    this.isHigh = false,
    this.isLow = false,
  });

  @override
  Widget build(BuildContext context) {
    Color valueColor = AppColors.textPrimary;
    if (isHigh) valueColor = AppColors.success;
    if (isLow) valueColor = AppColors.error;

    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: TextSizeConstants.xSmall,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '₹${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: TextSizeConstants.small,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
        width: 0.8, height: 28, color: AppColors.borderColor);
  }
}