Future<String> fetchSkeletonHtml(String url) async => '';
void injectSkeletonHtml(String elementId, String html) {}
String? getSkeletonParam() => null;
String? getWidgetNameParam() => null;
String? getRenderObjectNameParam() => null;
String? getElementNameParam() => null;
String? getParentDataNameParam() => null;
void setSkeletonUrl(String skeletonName, {String widgetName = '', String renderObjectName = '', String elementName = '', String parentDataName = ''}) {}
void clearSkeletonUrl() {}
Future<void> copySkeletonCode() async {}
String getNameInputValue(String id) => '';
void focusNameInput(String id) {}
void setupNameInputEnterKey(String id, void Function(String) callback) {}
void scrollToBottom(String elementId) {}
