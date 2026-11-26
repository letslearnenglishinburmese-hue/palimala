import 'package:flutter/material.dart';
import '../app_data.dart';

// Data download sheet
//
// Opened from Settings. Lists every downloadable data set together with its
// published hash and lets the user download or update only the chapters they
// need. The auto-update switch lives here as well.
class DataDownloadSheet extends StatefulWidget {
  final bool isMyanmar;

  const DataDownloadSheet({super.key, required this.isMyanmar});

  @override
  State<DataDownloadSheet> createState() => _DataDownloadSheetState();
}

class _DataDownloadSheetState extends State<DataDownloadSheet> {
  final Set<String> _busy = <String>{};
  bool _checking = false;
  bool _downloadingAll = false;

  Future<void> _checkForUpdates() async {
    final messenger = ScaffoldMessenger.of(context);
    final isMm = widget.isMyanmar;
    setState(() => _checking = true);
    try {
      await AppDataRepository.checkForUpdates();
      final updates = AppDataRepository.updatesAvailable;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            updates == 0
                ? (isMm
                      ? 'ဒေတာအားလုံး နောက်ဆုံးဖြစ်သည်'
                      : 'All data is up to date')
                : (isMm
                      ? 'မွမ်းမံရန် $updates ခု ရှိသည်'
                      : '$updates update(s) available'),
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(isMm ? 'စစ်ဆေး၍ မရပါ: $error' : 'Check failed: $error'),
        ),
      );
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _download(DatasetInfo dataset) async {
    if (_busy.contains(dataset.id)) return;
    final messenger = ScaffoldMessenger.of(context);
    final isMm = widget.isMyanmar;
    setState(() => _busy.add(dataset.id));
    try {
      final updated = await AppDataRepository.downloadDataset(dataset);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            updated
                ? (isMm
                      ? '${dataset.titleMm} ကို ရယူပြီးပါပြီ'
                      : 'Downloaded ${dataset.titleEn}')
                : (isMm
                      ? '${dataset.titleMm} နောက်ဆုံးဖြစ်နေပါသည်'
                      : '${dataset.titleEn} is already up to date'),
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(isMm ? 'ရယူ၍ မရပါ: $error' : 'Download failed: $error'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(dataset.id));
    }
  }

  Future<void> _downloadAll() async {
    final messenger = ScaffoldMessenger.of(context);
    final isMm = widget.isMyanmar;
    setState(() => _downloadingAll = true);
    try {
      final updated = await AppDataRepository.downloadAllUpdates();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isMm
                ? 'ဒေတာ $updated ခု မွမ်းမံပြီးပါပြီ'
                : 'Updated $updated data set(s)',
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isMm
                ? 'ဒေတာအချို့ကို မွမ်းမံ၍ မရပါ: $error'
                : 'Some datasets could not be updated: $error',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _downloadingAll = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMm = widget.isMyanmar;
    final theme = Theme.of(context);
    final datasets = AppDataRepository.datasets;
    final updates = AppDataRepository.updatesAvailable;
    final busy = _checking || _downloadingAll || _busy.isNotEmpty;

    return FractionallySizedBox(
      heightFactor: 0.85,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isMm ? 'ဒေတာ ဒေါင်းလုဒ်' : 'Data downloads',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isMm
                        ? 'လိုအပ်သော အခန်းများကို ရွေးချယ်ရယူနိုင်ပါသည်။ ဖိုင်တစ်ခုစီကို အလိုအလျောက် စစ်ဆေးပါသည်။'
                        : 'Download only the chapters you need. Every file is verified automatically.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            SwitchListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              secondary: const Icon(Icons.cloud_sync_outlined),
              title: const Text('Auto update'),
              subtitle: Text(
                isMm
                    ? 'အက်ပ်ဖွင့်ချိန်တွင် အလိုလျောက် ရယူပါမည်'
                    : 'Fetch newer data automatically on launch',
              ),
              value: AppDataRepository.autoUpdateEnabled,
              onChanged: (value) async {
                await AppDataRepository.setAutoUpdate(value);
                if (!mounted) return;
                setState(() {});
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _checking ? null : _checkForUpdates,
                      icon: _checking
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_rounded),
                      label: Text(
                        isMm ? 'အသစ် စစ်ဆေးရန်' : 'Check for updates',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: (updates == 0 || busy) ? null : _downloadAll,
                      icon: _downloadingAll
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download_rounded),
                      label: Text(isMm ? 'အားလုံး ရယူရန်' : 'Download all'),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: datasets.isEmpty
                  ? Center(
                      child: Text(isMm ? 'ဒေတာ မတွေ့ပါ' : 'No datasets found'),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: datasets.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) =>
                          _buildDatasetTile(datasets[index], isMm),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatasetTile(DatasetInfo dataset, bool isMm) {
    final theme = Theme.of(context);
    final isUpToDate =
        AppDataRepository.statusOf(dataset) == DatasetStatus.upToDate;
    final isBusy = _busy.contains(dataset.id);
    final actionLabel = AppDataRepository.hasDownloadedCopy(dataset)
        ? (isMm ? 'မွမ်းမံရန်' : 'Update')
        : (isMm ? 'ရယူရန်' : 'Download');

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.secondaryContainer,
        child: Icon(
          dataset.icon,
          color: theme.colorScheme.onSecondaryContainer,
        ),
      ),
      title: Text(
        isMm ? dataset.titleMm : dataset.titleEn,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isUpToDate
                ? (isMm ? 'နောက်ဆုံးဖြစ်သည်' : 'Up to date')
                : (isMm ? 'မွမ်းမံရန် ရှိသည်' : 'Update available'),
            style: TextStyle(
              color: isUpToDate
                  ? Colors.green.shade700
                  : theme.colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      trailing: isUpToDate
          ? const Icon(Icons.check_circle_rounded, color: Colors.green)
          : isBusy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : FilledButton.tonal(
              onPressed: () => _download(dataset),
              child: Text(actionLabel),
            ),
      onTap: isUpToDate || isBusy ? null : () => _download(dataset),
    );
  }
}
