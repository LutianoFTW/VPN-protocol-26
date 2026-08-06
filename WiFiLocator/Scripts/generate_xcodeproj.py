#!/usr/bin/env python3
"""Generate WiFiLocator.xcodeproj/project.pbxproj for arm64 macOS.

Uses SOURCE_ROOT-relative paths for every file so CI/xcodebuild resolves
inputs reliably (avoids group-relative path bugs with WMO builds).
"""

from pathlib import Path
import uuid

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "WiFiLocator.xcodeproj" / "project.pbxproj"

# Paths relative to the Xcode project directory (WiFiLocator/)
SOURCES = [
    "WiFiLocator/WiFiLocatorApp.swift",
    "WiFiLocator/ContentView.swift",
    "WiFiLocator/Theme.swift",
    "WiFiLocator/Models/AccessPoint.swift",
    "WiFiLocator/Models/LocationEstimate.swift",
    "WiFiLocator/Models/ScanExport.swift",
    "WiFiLocator/Services/AppModel.swift",
    "WiFiLocator/Services/WiFiScanner.swift",
    "WiFiLocator/Services/NetworkInfoService.swift",
    "WiFiLocator/Services/Geolocation/GeolocationService.swift",
    "WiFiLocator/Services/Geolocation/AppleWPSProvider.swift",
    "WiFiLocator/Services/Geolocation/BeaconDBProvider.swift",
    "WiFiLocator/Services/Geolocation/GoogleGeolocationProvider.swift",
    "WiFiLocator/Services/Geolocation/IPGeolocationProvider.swift",
    "WiFiLocator/Services/Geolocation/ReverseGeocoder.swift",
    "WiFiLocator/Views/MapLocationView.swift",
    "WiFiLocator/Views/SettingsView.swift",
]


def gid(name: str) -> str:
    return uuid.uuid5(uuid.NAMESPACE_URL, f"wifilocation:{name}").hex[:24].upper()


project_id = gid("project")
target_id = gid("target")
sources_phase = gid("sources")
resources_phase = gid("resources")
frameworks_phase = gid("frameworks")
product_ref = gid("product")
main_group = gid("main_group")
src_group = gid("src_group")
products_group = gid("products_group")
models_group = gid("models_group")
services_group = gid("services_group")
geo_group = gid("geo_group")
views_group = gid("views_group")
resources_group = gid("resources_group")
project_config_list = gid("project_config_list")
target_config_list = gid("target_config_list")
project_debug = gid("project_debug")
project_release = gid("project_release")
target_debug = gid("target_debug")
target_release = gid("target_release")
assets_ref = gid("assets")
info_ref = gid("info")
entitlements_ref = gid("entitlements")

frameworks = [
    ("CoreWLAN.framework", gid("fw_corewlan")),
    ("CoreLocation.framework", gid("fw_corelocation")),
    ("MapKit.framework", gid("fw_mapkit")),
    ("SystemConfiguration.framework", gid("fw_sysconfig")),
    ("Network.framework", gid("fw_network")),
]

file_entries = []
build_files = []
for path in SOURCES:
    fid = gid(f"file:{path}")
    bid = gid(f"build:{path}")
    name = Path(path).name
    file_entries.append((path, fid, name))
    build_files.append((bid, fid, name))


def file_id(path: str) -> str:
    return gid(f"file:{path}")


assets_build = gid("build:assets")
assets_path = "WiFiLocator/Resources/Assets.xcassets"
info_path = "WiFiLocator/Info.plist"
entitlements_path = "WiFiLocator/WiFiLocator.entitlements"

lines: list[str] = []
lines.append("// !$*UTF8*$!")
lines.append("{")
lines.append("\tarchiveVersion = 1;")
lines.append("\tclasses = {")
lines.append("\t};")
lines.append("\tobjectVersion = 56;")
lines.append("\tobjects = {")
lines.append("")

lines.append("/* Begin PBXBuildFile section */")
for bid, fid, name in build_files:
    lines.append(f"\t\t{bid} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {fid} /* {name} */; }};")
for fname, fid in frameworks:
    bid = gid(f"buildfw:{fname}")
    lines.append(f"\t\t{bid} /* {fname} in Frameworks */ = {{isa = PBXBuildFile; fileRef = {fid} /* {fname} */; }};")
lines.append(f"\t\t{assets_build} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {assets_ref} /* Assets.xcassets */; }};")
lines.append("/* End PBXBuildFile section */")
lines.append("")

lines.append("/* Begin PBXFileReference section */")
lines.append(
    f"\t\t{product_ref} /* WiFiLocator.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = WiFiLocator.app; sourceTree = BUILT_PRODUCTS_DIR; }};"
)
for path, fid, name in file_entries:
    lines.append(
        f"\t\t{fid} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; name = {name}; path = {path}; sourceTree = SOURCE_ROOT; }};"
    )
lines.append(
    f"\t\t{assets_ref} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; name = Assets.xcassets; path = {assets_path}; sourceTree = SOURCE_ROOT; }};"
)
lines.append(
    f"\t\t{info_ref} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; name = Info.plist; path = {info_path}; sourceTree = SOURCE_ROOT; }};"
)
lines.append(
    f"\t\t{entitlements_ref} /* WiFiLocator.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; name = WiFiLocator.entitlements; path = {entitlements_path}; sourceTree = SOURCE_ROOT; }};"
)
for fname, fid in frameworks:
    lines.append(
        f"\t\t{fid} /* {fname} */ = {{isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = {fname}; path = System/Library/Frameworks/{fname}; sourceTree = SDKROOT; }};"
    )
lines.append("/* End PBXFileReference section */")
lines.append("")

lines.append("/* Begin PBXFrameworksBuildPhase section */")
lines.append(f"\t\t{frameworks_phase} /* Frameworks */ = {{")
lines.append("\t\t\tisa = PBXFrameworksBuildPhase;")
lines.append("\t\t\tbuildActionMask = 2147483647;")
lines.append("\t\t\tfiles = (")
for fname, fid in frameworks:
    bid = gid(f"buildfw:{fname}")
    lines.append(f"\t\t\t\t{bid} /* {fname} in Frameworks */,")
lines.append("\t\t\t);")
lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
lines.append("\t\t};")
lines.append("/* End PBXFrameworksBuildPhase section */")
lines.append("")

lines.append("/* Begin PBXGroup section */")
lines.append(f"\t\t{main_group} = {{")
lines.append("\t\t\tisa = PBXGroup;")
lines.append("\t\t\tchildren = (")
lines.append(f"\t\t\t\t{src_group} /* WiFiLocator */,")
lines.append(f"\t\t\t\t{products_group} /* Products */,")
lines.append("\t\t\t);")
lines.append("\t\t\tsourceTree = \"<group>\";")
lines.append("\t\t};")

lines.append(f"\t\t{products_group} /* Products */ = {{")
lines.append("\t\t\tisa = PBXGroup;")
lines.append("\t\t\tchildren = (")
lines.append(f"\t\t\t\t{product_ref} /* WiFiLocator.app */,")
lines.append("\t\t\t);")
lines.append("\t\t\tname = Products;")
lines.append("\t\t\tsourceTree = \"<group>\";")
lines.append("\t\t};")

lines.append(f"\t\t{src_group} /* WiFiLocator */ = {{")
lines.append("\t\t\tisa = PBXGroup;")
lines.append("\t\t\tchildren = (")
lines.append(f"\t\t\t\t{file_id('WiFiLocator/WiFiLocatorApp.swift')} /* WiFiLocatorApp.swift */,")
lines.append(f"\t\t\t\t{file_id('WiFiLocator/ContentView.swift')} /* ContentView.swift */,")
lines.append(f"\t\t\t\t{file_id('WiFiLocator/Theme.swift')} /* Theme.swift */,")
lines.append(f"\t\t\t\t{models_group} /* Models */,")
lines.append(f"\t\t\t\t{services_group} /* Services */,")
lines.append(f"\t\t\t\t{views_group} /* Views */,")
lines.append(f"\t\t\t\t{resources_group} /* Resources */,")
lines.append(f"\t\t\t\t{info_ref} /* Info.plist */,")
lines.append(f"\t\t\t\t{entitlements_ref} /* WiFiLocator.entitlements */,")
lines.append("\t\t\t);")
lines.append("\t\t\tname = WiFiLocator;")
lines.append("\t\t\tsourceTree = \"<group>\";")
lines.append("\t\t};")

lines.append(f"\t\t{models_group} /* Models */ = {{")
lines.append("\t\t\tisa = PBXGroup;")
lines.append("\t\t\tchildren = (")
for p in [
    "WiFiLocator/Models/AccessPoint.swift",
    "WiFiLocator/Models/LocationEstimate.swift",
    "WiFiLocator/Models/ScanExport.swift",
]:
    lines.append(f"\t\t\t\t{file_id(p)} /* {Path(p).name} */,")
lines.append("\t\t\t);")
lines.append("\t\t\tname = Models;")
lines.append("\t\t\tsourceTree = \"<group>\";")
lines.append("\t\t};")

lines.append(f"\t\t{services_group} /* Services */ = {{")
lines.append("\t\t\tisa = PBXGroup;")
lines.append("\t\t\tchildren = (")
for p in [
    "WiFiLocator/Services/AppModel.swift",
    "WiFiLocator/Services/WiFiScanner.swift",
    "WiFiLocator/Services/NetworkInfoService.swift",
]:
    lines.append(f"\t\t\t\t{file_id(p)} /* {Path(p).name} */,")
lines.append(f"\t\t\t\t{geo_group} /* Geolocation */,")
lines.append("\t\t\t);")
lines.append("\t\t\tname = Services;")
lines.append("\t\t\tsourceTree = \"<group>\";")
lines.append("\t\t};")

lines.append(f"\t\t{geo_group} /* Geolocation */ = {{")
lines.append("\t\t\tisa = PBXGroup;")
lines.append("\t\t\tchildren = (")
for p in [
    "WiFiLocator/Services/Geolocation/GeolocationService.swift",
    "WiFiLocator/Services/Geolocation/AppleWPSProvider.swift",
    "WiFiLocator/Services/Geolocation/BeaconDBProvider.swift",
    "WiFiLocator/Services/Geolocation/GoogleGeolocationProvider.swift",
    "WiFiLocator/Services/Geolocation/IPGeolocationProvider.swift",
    "WiFiLocator/Services/Geolocation/ReverseGeocoder.swift",
]:
    lines.append(f"\t\t\t\t{file_id(p)} /* {Path(p).name} */,")
lines.append("\t\t\t);")
lines.append("\t\t\tname = Geolocation;")
lines.append("\t\t\tsourceTree = \"<group>\";")
lines.append("\t\t};")

lines.append(f"\t\t{views_group} /* Views */ = {{")
lines.append("\t\t\tisa = PBXGroup;")
lines.append("\t\t\tchildren = (")
for p in [
    "WiFiLocator/Views/MapLocationView.swift",
    "WiFiLocator/Views/SettingsView.swift",
]:
    lines.append(f"\t\t\t\t{file_id(p)} /* {Path(p).name} */,")
lines.append("\t\t\t);")
lines.append("\t\t\tname = Views;")
lines.append("\t\t\tsourceTree = \"<group>\";")
lines.append("\t\t};")

lines.append(f"\t\t{resources_group} /* Resources */ = {{")
lines.append("\t\t\tisa = PBXGroup;")
lines.append("\t\t\tchildren = (")
lines.append(f"\t\t\t\t{assets_ref} /* Assets.xcassets */,")
lines.append("\t\t\t);")
lines.append("\t\t\tname = Resources;")
lines.append("\t\t\tsourceTree = \"<group>\";")
lines.append("\t\t};")
lines.append("/* End PBXGroup section */")
lines.append("")

lines.append("/* Begin PBXNativeTarget section */")
lines.append(f"\t\t{target_id} /* WiFiLocator */ = {{")
lines.append("\t\t\tisa = PBXNativeTarget;")
lines.append(f"\t\t\tbuildConfigurationList = {target_config_list} /* Build configuration list for PBXNativeTarget \"WiFiLocator\" */;")
lines.append("\t\t\tbuildPhases = (")
lines.append(f"\t\t\t\t{sources_phase} /* Sources */,")
lines.append(f"\t\t\t\t{frameworks_phase} /* Frameworks */,")
lines.append(f"\t\t\t\t{resources_phase} /* Resources */,")
lines.append("\t\t\t);")
lines.append("\t\t\tbuildRules = (")
lines.append("\t\t\t);")
lines.append("\t\t\tdependencies = (")
lines.append("\t\t\t);")
lines.append("\t\t\tname = WiFiLocator;")
lines.append("\t\t\tproductName = WiFiLocator;")
lines.append(f"\t\t\tproductReference = {product_ref} /* WiFiLocator.app */;")
lines.append("\t\t\tproductType = \"com.apple.product-type.application\";")
lines.append("\t\t};")
lines.append("/* End PBXNativeTarget section */")
lines.append("")

lines.append("/* Begin PBXProject section */")
lines.append(f"\t\t{project_id} /* Project object */ = {{")
lines.append("\t\t\tisa = PBXProject;")
lines.append("\t\t\tattributes = {")
lines.append("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
lines.append("\t\t\t\tLastSwiftUpdateCheck = 1540;")
lines.append("\t\t\t\tLastUpgradeCheck = 1540;")
lines.append("\t\t\t};")
lines.append(f"\t\t\tbuildConfigurationList = {project_config_list} /* Build configuration list for PBXProject \"WiFiLocator\" */;")
lines.append("\t\t\tcompatibilityVersion = \"Xcode 14.0\";")
lines.append("\t\t\tdevelopmentRegion = en;")
lines.append("\t\t\thasScannedForEncodings = 0;")
lines.append("\t\t\tknownRegions = (")
lines.append("\t\t\t\ten,")
lines.append("\t\t\t\tBase,")
lines.append("\t\t\t);")
lines.append(f"\t\t\tmainGroup = {main_group};")
lines.append(f"\t\t\tproductRefGroup = {products_group} /* Products */;")
lines.append("\t\t\tprojectDirPath = \"\";")
lines.append("\t\t\tprojectRoot = \"\";")
lines.append("\t\t\ttargets = (")
lines.append(f"\t\t\t\t{target_id} /* WiFiLocator */,")
lines.append("\t\t\t);")
lines.append("\t\t};")
lines.append("/* End PBXProject section */")
lines.append("")

lines.append("/* Begin PBXResourcesBuildPhase section */")
lines.append(f"\t\t{resources_phase} /* Resources */ = {{")
lines.append("\t\t\tisa = PBXResourcesBuildPhase;")
lines.append("\t\t\tbuildActionMask = 2147483647;")
lines.append("\t\t\tfiles = (")
lines.append(f"\t\t\t\t{assets_build} /* Assets.xcassets in Resources */,")
lines.append("\t\t\t);")
lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
lines.append("\t\t};")
lines.append("/* End PBXResourcesBuildPhase section */")
lines.append("")

lines.append("/* Begin PBXSourcesBuildPhase section */")
lines.append(f"\t\t{sources_phase} /* Sources */ = {{")
lines.append("\t\t\tisa = PBXSourcesBuildPhase;")
lines.append("\t\t\tbuildActionMask = 2147483647;")
lines.append("\t\t\tfiles = (")
for bid, fid, name in build_files:
    lines.append(f"\t\t\t\t{bid} /* {name} in Sources */,")
lines.append("\t\t\t);")
lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
lines.append("\t\t};")
lines.append("/* End PBXSourcesBuildPhase section */")
lines.append("")

common_project = """
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_NO_COMMON_BLOCKS = YES;
				MACOSX_DEPLOYMENT_TARGET = 14.0;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = macosx;
				SWIFT_VERSION = 5.0;
""".rstrip("\n")

lines.append("/* Begin XCBuildConfiguration section */")
lines.append(f"\t\t{project_debug} /* Debug */ = {{")
lines.append("\t\t\tisa = XCBuildConfiguration;")
lines.append("\t\t\tbuildSettings = {")
lines.append(common_project)
lines.append("\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = \"DEBUG $(inherited)\";")
lines.append("\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-Onone\";")
lines.append("\t\t\t};")
lines.append("\t\t\tname = Debug;")
lines.append("\t\t};")

lines.append(f"\t\t{project_release} /* Release */ = {{")
lines.append("\t\t\tisa = XCBuildConfiguration;")
lines.append("\t\t\tbuildSettings = {")
lines.append(common_project.replace("ONLY_ACTIVE_ARCH = YES;", "ONLY_ACTIVE_ARCH = NO;"))
lines.append("\t\t\t\tDEBUG_INFORMATION_FORMAT = \"dwarf-with-dsym\";")
lines.append("\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;")
lines.append("\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-O\";")
lines.append("\t\t\t};")
lines.append("\t\t\tname = Release;")
lines.append("\t\t};")

target_settings = f"""
				ARCHS = arm64;
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_ENTITLEMENTS = {entitlements_path};
				CODE_SIGN_IDENTITY = "-";
				CODE_SIGN_STYLE = Manual;
				COMBINE_HIDPI_IMAGES = YES;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				ENABLE_HARDENED_RUNTIME = YES;
				EXCLUDED_ARCHS = \"x86_64 i386\";
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = {info_path};
				LD_RUNPATH_SEARCH_PATHS = (
					\"$(inherited)\",
					\"@executable_path/../Frameworks\",
				);
				MACOSX_DEPLOYMENT_TARGET = 14.0;
				MARKETING_VERSION = 1.0.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.wifilocator.app;
				PRODUCT_NAME = \"$(TARGET_NAME)\";
				PROVISIONING_PROFILE_SPECIFIER = "";
				SUPPORTED_PLATFORMS = macosx;
				SUPPORTS_MACCATALYST = NO;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
""".rstrip("\n")

lines.append(f"\t\t{target_debug} /* Debug */ = {{")
lines.append("\t\t\tisa = XCBuildConfiguration;")
lines.append("\t\t\tbuildSettings = {")
lines.append(target_settings)
lines.append("\t\t\t};")
lines.append("\t\t\tname = Debug;")
lines.append("\t\t};")

lines.append(f"\t\t{target_release} /* Release */ = {{")
lines.append("\t\t\tisa = XCBuildConfiguration;")
lines.append("\t\t\tbuildSettings = {")
lines.append(target_settings)
lines.append("\t\t\t};")
lines.append("\t\t\tname = Release;")
lines.append("\t\t};")
lines.append("/* End XCBuildConfiguration section */")
lines.append("")

lines.append("/* Begin XCConfigurationList section */")
lines.append(f"\t\t{project_config_list} /* Build configuration list for PBXProject \"WiFiLocator\" */ = {{")
lines.append("\t\t\tisa = XCConfigurationList;")
lines.append("\t\t\tbuildConfigurations = (")
lines.append(f"\t\t\t\t{project_debug} /* Debug */,")
lines.append(f"\t\t\t\t{project_release} /* Release */,")
lines.append("\t\t\t);")
lines.append("\t\t\tdefaultConfigurationIsVisible = 0;")
lines.append("\t\t\tdefaultConfigurationName = Release;")
lines.append("\t\t};")
lines.append(f"\t\t{target_config_list} /* Build configuration list for PBXNativeTarget \"WiFiLocator\" */ = {{")
lines.append("\t\t\tisa = XCConfigurationList;")
lines.append("\t\t\tbuildConfigurations = (")
lines.append(f"\t\t\t\t{target_debug} /* Debug */,")
lines.append(f"\t\t\t\t{target_release} /* Release */,")
lines.append("\t\t\t);")
lines.append("\t\t\tdefaultConfigurationIsVisible = 0;")
lines.append("\t\t\tdefaultConfigurationName = Release;")
lines.append("\t\t};")
lines.append("/* End XCConfigurationList section */")
lines.append("\t};")
lines.append(f"\trootObject = {project_id} /* Project object */;")
lines.append("}")

# Verify every source path exists before writing.
missing = [p for p in SOURCES if not (ROOT / p).is_file()]
if missing:
    raise SystemExit("Missing source files:\n  " + "\n  ".join(missing))
if not (ROOT / assets_path).is_dir():
    raise SystemExit(f"Missing assets: {assets_path}")

OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text("\n".join(lines) + "\n")
print(f"Wrote {OUT}")
print(f"Sources: {len(SOURCES)}")
