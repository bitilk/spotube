import 'package:badges/badges.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:fl_query_hooks/fl_query_hooks.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:platform_ui/platform_ui.dart';
import 'package:spotube/collections/side_bar_tiles.dart';
import 'package:spotube/components/shared/image/universal_image.dart';
import 'package:spotube/hooks/use_breakpoints.dart';
import 'package:spotube/provider/auth_provider.dart';
import 'package:spotube/provider/downloader_provider.dart';
import 'package:spotube/provider/spotify_provider.dart';

import 'package:spotube/provider/user_preferences_provider.dart';
import 'package:spotube/services/queries/queries.dart';
import 'package:spotube/utils/platform.dart';
import 'package:spotube/utils/type_conversion_utils.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent_ui;

final sidebarExtendedStateProvider = StateProvider<bool?>((ref) => null);

class Sidebar extends HookConsumerWidget {
  final int selectedIndex;
  final void Function(int) onSelectedIndexChanged;
  final Widget child;

  const Sidebar({
    required this.selectedIndex,
    required this.onSelectedIndexChanged,
    required this.child,
    Key? key,
  }) : super(key: key);

  static Widget brandLogo() {
    return Image.asset(
      "assets/spotube-logo.png",
      height: 50,
      width: 50,
    );
  }

  static void goToSettings(BuildContext context) {
    GoRouter.of(context).go("/settings");
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final breakpoints = useBreakpoints();
    final extended = useState(false);

    final downloadCount = ref.watch(
      downloaderProvider.select((s) => s.currentlyRunning),
    );
    final forceExtended = ref.watch(sidebarExtendedStateProvider);

    useEffect(() {
      if (forceExtended != null) {
        if (extended.value != forceExtended) {
          extended.value = forceExtended;
        }
        return;
      }
      if (breakpoints.isMd && extended.value) {
        extended.value = false;
      } else if (breakpoints.isMoreThanOrEqualTo(Breakpoints.lg) &&
          !extended.value) {
        extended.value = true;
      }
      return null;
    });

    final layoutMode =
        ref.watch(userPreferencesProvider.select((s) => s.layoutMode));

    if (layoutMode == LayoutMode.compact ||
        (breakpoints.isSm && layoutMode == LayoutMode.adaptive)) {
      return PlatformScaffold(body: child);
    }

    void toggleExtended() =>
        ref.read(sidebarExtendedStateProvider.notifier).state =
            !(forceExtended ?? extended.value);

    return SafeArea(
      top: false,
      child: PlatformSidebar(
        currentIndex: selectedIndex,
        onIndexChanged: onSelectedIndexChanged,
        body: Map.fromEntries(
          sidebarTileList.map(
            (e) {
              final icon = Icon(e.icon);
              return MapEntry(
                PlatformSidebarItem(
                  icon: Badge(
                    badgeColor: PlatformTheme.of(context).primaryColor!,
                    showBadge: e.title == "Library" && downloadCount > 0,
                    badgeContent: Text(
                      downloadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                    ),
                    child: icon,
                  ),
                  title: Text(
                    e.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                child,
              );
            },
          ),
        ),
        expanded: extended.value,
        header: Column(
          children: [
            if (kIsMacOS)
              SizedBox(
                height: appWindow.titleBarHeight,
                width: extended.value ? 256 : 80,
                child: MoveWindow(
                  child: !extended.value
                      ? Center(
                          child: PlatformIconButton(
                            icon: const Icon(Icons.menu_rounded),
                            onPressed: toggleExtended,
                          ),
                        )
                      : null,
                ),
              ),
            if (!kIsDesktop && !extended.value)
              Center(
                child: PlatformIconButton(
                  icon: const Icon(Icons.menu_rounded),
                  onPressed: toggleExtended,
                ),
              ),
            (extended.value)
                ? Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        brandLogo(),
                        const SizedBox(
                          width: 10,
                        ),
                        PlatformText.headline("Spotube"),
                        PlatformIconButton(
                          icon: const Icon(Icons.menu_rounded),
                          onPressed: toggleExtended,
                        ),
                      ],
                    ),
                  )
                : brandLogo(),
          ],
        ),
        windowsFooterItems: [
          fluent_ui.PaneItemAction(
            icon: const fluent_ui.Icon(fluent_ui.FluentIcons.settings),
            onTap: () => goToSettings(context),
          ),
        ],
        footer: SidebarFooter(extended: extended.value),
      ),
    );
  }
}

class SidebarFooter extends HookConsumerWidget {
  final bool extended;
  const SidebarFooter({
    Key? key,
    required this.extended,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, ref) {
    final auth = ref.watch(authProvider);

    return SizedBox(
      width: extended ? 256 : 80,
      child: HookBuilder(
        builder: (context) {
          final me = useQuery(
            job: Queries.user.me,
            externalData: ref.watch(spotifyProvider),
          );
          final data = me.data;

          final avatarImg = TypeConversionUtils.image_X_UrlString(
            data?.images,
            index: (data?.images?.length ?? 1) - 1,
            placeholder: ImagePlaceholder.artist,
          );

          useEffect(() {
            if (auth.isLoggedIn && !me.hasData) {
              me.setExternalData(ref.read(spotifyProvider));
              me.refetch();
            }
            return;
          }, [auth.isLoggedIn, me.hasData]);

          if (extended) {
            return Padding(
                padding: const EdgeInsets.all(16).copyWith(left: 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (auth.isLoggedIn && data == null)
                      const Center(
                        child: PlatformCircularProgressIndicator(),
                      )
                    else if (data != null)
                      Flexible(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            CircleAvatar(
                              backgroundImage:
                                  UniversalImage.imageProvider(avatarImg),
                              onBackgroundImageError: (exception, stackTrace) =>
                                  Image.asset(
                                "assets/user-placeholder.png",
                                height: 16,
                                width: 16,
                              ),
                            ),
                            const SizedBox(
                              width: 10,
                            ),
                            Flexible(
                              child: Text(
                                data.displayName ?? "Guest",
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.fade,
                                style: PlatformTheme.of(context)
                                    .textTheme
                                    ?.body
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    PlatformIconButton(
                        icon: const Icon(Icons.settings_outlined),
                        onPressed: () => Sidebar.goToSettings(context)),
                  ],
                ));
          } else {
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: InkWell(
                onTap: () => Sidebar.goToSettings(context),
                child: CircleAvatar(
                  backgroundImage: UniversalImage.imageProvider(avatarImg),
                  onBackgroundImageError: (exception, stackTrace) =>
                      Image.asset(
                    "assets/user-placeholder.png",
                    height: 16,
                    width: 16,
                  ),
                ),
              ),
            );
          }
        },
      ),
    );
  }
}
