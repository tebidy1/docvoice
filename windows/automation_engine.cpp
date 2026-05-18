#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <ole2.h>
#include <comdef.h>
#include <atlbase.h>
#include <atlcomcli.h>
#include <UIAutomation.h>
#include <string>
#include <vector>
#include <sstream>
#include <iostream>
#include <algorithm>
#include <cctype>

#pragma comment(lib, "oleacc.lib")
#pragma comment(lib, "UIAutomationCore.lib")
#pragma comment(lib, "ole32.lib")

// Forward declarations
std::string EscapeJson(const std::string& s);
void OutputJson(const std::string& json);
void Log(const std::string& msg);

    // Normalize Arabic text for matching
std::string NormalizeArabic(const std::string& text) {
    std::string result = text;
    result.erase(
        std::remove_if(result.begin(), result.end(), [](unsigned char c) {
            return c >= 0x64B && c <= 0x65F;
        }),
        result.end()
    );
    for (size_t i = 0; i < result.size(); i++) {
        unsigned char c = (unsigned char)result[i];
        if (c == 0xD8 && i + 1 < result.size()) {
            unsigned char next = (unsigned char)result[i + 1];
            if (next == 0xA2 || next == 0xA3 || next == 0xA5 || next == 0xA7)
                result[i + 1] = (char)0xA7;
            if (next == 0x89)
                result[i + 1] = (char)0x8A;
            if (next == 0x88)
                result[i + 1] = (char)0x88;
        }
    }
    return result;
}

bool ContainsIgnoreCase(const std::string& haystack, const std::string& needle) {
    auto it = std::search(
        haystack.begin(), haystack.end(),
        needle.begin(), needle.end(),
        [](char ch1, char ch2) { return std::tolower(ch1) == std::tolower(ch2); }
    );
    return it != haystack.end();
}

std::string NormalizeLabel(const std::string& label) {
    std::string result = label;
    for (auto& c : result) {
        if (c == '_') c = ' ';
    }
    return result;
}

struct ElementInfo {
    std::wstring name;
    std::wstring automationId;
    std::wstring controlType;
    std::wstring className;
    RECT boundingRect = {};
    std::wstring value;
};

std::string WStringToString(const std::wstring& wstr) {
    if (wstr.empty()) return "";
    int len = WideCharToMultiByte(CP_UTF8, 0, wstr.c_str(), -1, nullptr, 0, nullptr, nullptr);
    if (len <= 0) return "";
    std::vector<char> buf(len);
    WideCharToMultiByte(CP_UTF8, 0, wstr.c_str(), -1, buf.data(), len, nullptr, nullptr);
    return std::string(buf.data());
}

std::string RectToJson(const RECT& r) {
    std::ostringstream os;
    os << "{\"x\":" << r.left << ",\"y\":" << r.top
       << ",\"width\":" << (r.right - r.left)
       << ",\"height\":" << (r.bottom - r.top) << "}";
    return os.str();
}

class AutomationEngine {
private:
    CComPtr<IUIAutomation> _automation;

    struct EnumData {
        std::ostringstream& json;
        bool first;
    };

    struct FindData {
        const std::string& appName;
        HWND& result;
    };

public:
    AutomationEngine() {
        HRESULT hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
        if (FAILED(hr) && hr != RPC_E_CHANGED_MODE) {
            Log("CoInitializeEx failed");
            return;
        }

        hr = CoCreateInstance(CLSID_CUIAutomation, nullptr, CLSCTX_INPROC_SERVER,
                              IID_IUIAutomation, (void**)&_automation);
        if (FAILED(hr) || !_automation) {
            Log("CoCreateInstance IUIAutomation failed");
        }
    }

    ~AutomationEngine() {
        CoUninitialize();
    }

    bool IsValid() const { return _automation != nullptr; }

    std::string ListApps() {
        std::ostringstream json;
        json << "{\"success\":true,\"data\":[";
        EnumData data = {json, true};

        EnumWindows([](HWND hwnd, LPARAM lParam) -> BOOL {
            auto& data = *reinterpret_cast<EnumData*>(lParam);
            if (!IsWindowVisible(hwnd)) return TRUE;

            // Get process info FIRST — before filtering by title
            DWORD pid = 0;
            GetWindowThreadProcessId(hwnd, &pid);
            HANDLE hProcess = OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, FALSE, pid);
            std::wstring processName;
            if (hProcess) {
                wchar_t exeName[MAX_PATH] = {0};
                DWORD size = MAX_PATH;
                if (QueryFullProcessImageNameW(hProcess, 0, exeName, &size)) {
                    std::wstring fullPath(exeName);
                    auto pos = fullPath.find_last_of(L"\\/");
                    if (pos != std::wstring::npos)
                        processName = fullPath.substr(pos + 1);
                    auto dotPos = processName.find_last_of(L".");
                    if (dotPos != std::wstring::npos)
                        processName = processName.substr(0, dotPos);
                }
                CloseHandle(hProcess);
            }
            if (processName.empty()) processName = L"unknown";

            // Get window title
            int len = GetWindowTextLengthW(hwnd);
            std::wstring title;
            if (len > 0) {
                title.resize(len);
                GetWindowTextW(hwnd, &title[0], len + 1);
            }

            wchar_t className[256];
            GetClassNameW(hwnd, className, 256);
            std::wstring cls(className);

            // Skip only our own windows
            if (ContainsIgnoreCase(WStringToString(title), "docvoice") ||
                ContainsIgnoreCase(WStringToString(title), "scribeflow"))
                return TRUE;

            // Skip only if both title AND process name are empty/unknown
            if (title.empty() && processName == L"unknown") return TRUE;

            if (!data.first) data.json << ",";
            data.first = false;
            data.json << "{"
                      << "\"name\":\"" << EscapeJson(WStringToString(processName)) << "\","
                      << "\"processId\":" << pid << ","
                      << "\"mainWindowTitle\":\"" << EscapeJson(WStringToString(title)) << "\","
                      << "\"className\":\"" << EscapeJson(WStringToString(cls)) << "\""
                      << "}";

            return TRUE;
        }, (LPARAM)&data);

        json << "],\"message\":\"OK\"}";
        return json.str();
    }

        std::string InjectIntoApp(const std::string& appName, const std::string& label, const std::string& value) {
        HWND hwnd = FindTargetWindow(appName);
        if (!hwnd) {
            return "{\"success\":false,\"error\":\"Window not found: " + EscapeJson(appName) + "\"}";
        }

        return InjectIntoWindow(hwnd, label, value);
    }

    std::string ScanWindow(const std::string& appName) {
        HWND hwnd = FindTargetWindow(appName);
        if (!hwnd) {
            return "{\"success\":false,\"error\":\"Window not found: " + EscapeJson(appName) + "\"}";
        }

        CComPtr<IUIAutomationElement> rootElement;
        HRESULT hr = _automation->ElementFromHandle(reinterpret_cast<UIA_HWND>(hwnd), &rootElement);
        if (FAILED(hr) || !rootElement) {
            return "{\"success\":false,\"error\":\"Could not get root element\"}";
        }

        CComPtr<IUIAutomationCondition> trueCond;
        _automation->CreateTrueCondition(&trueCond);

        CComPtr<IUIAutomationTreeWalker> walker;
        _automation->CreateTreeWalker(trueCond, &walker);

        std::ostringstream json;
        json << "{\"success\":true,\"data\":[";
        bool first = true;

        EnumerateElements(rootElement, walker, 0, json, first);

        json << "],\"message\":\"OK\"}";
        return json.str();
    }

    std::string FindFieldsByLabels(const std::string& appName, const std::string& labelsCsv) {
        HWND hwnd = FindTargetWindow(appName);
        if (!hwnd) {
            return "{\"success\":false,\"data\":[],\"error\":\"Window not found: " + EscapeJson(appName) + "\"}";
        }

        CComPtr<IUIAutomationElement> rootElement;
        HRESULT hr = _automation->ElementFromHandle(reinterpret_cast<UIA_HWND>(hwnd), &rootElement);
        if (FAILED(hr) || !rootElement) {
            return "{\"success\":false,\"data\":[],\"error\":\"Could not get root element\"}";
        }

        // Parse labels CSV
        std::vector<std::string> labels;
        std::stringstream ss(labelsCsv);
        std::string item;
        while (std::getline(ss, item, ',')) {
            labels.push_back(NormalizeArabic(NormalizeLabel(item)));
        }

        CComPtr<IUIAutomationCondition> trueCond;
        _automation->CreateTrueCondition(&trueCond);

        CComPtr<IUIAutomationTreeWalker> walker;
        _automation->CreateTreeWalker(trueCond, &walker);

        std::ostringstream json;
        json << "{\"success\":true,\"data\":[";
        bool first = true;

        for (const auto& label : labels) {
            if (!first) json << ",";
            first = false;
            json << "{";

            CComPtr<IUIAutomationElement> edit = FindEditNearLabel(rootElement, label);
            if (edit) {
                ElementInfo info = GetElementInfo(edit);
                json << "\"matched\":true,"
                     << "\"label\":\"" << EscapeJson(label) << "\","
                     << "\"name\":\"" << EscapeJson(WStringToString(info.name)) << "\","
                     << "\"automationId\":\"" << EscapeJson(WStringToString(info.automationId)) << "\","
                     << "\"controlType\":\"" << EscapeJson(WStringToString(info.controlType)) << "\","
                     << "\"value\":\"" << EscapeJson(WStringToString(info.value)) << "\"";
            } else {
                json << "\"matched\":false,"
                     << "\"label\":\"" << EscapeJson(label) << "\"";
            }
            json << "}";
        }

        json << "],\"message\":\"OK\"}";
        return json.str();
    }

private:
    void EnumerateElements(IUIAutomationElement* element, IUIAutomationTreeWalker* walker,
                           int depth, std::ostringstream& json, bool& first) {
        if (depth > 12) return; // Limit depth to avoid excessive output

        CComPtr<IUIAutomationElement> child;
        walker->GetFirstChildElement(element, &child);

        while (child) {
            ElementInfo info = GetElementInfo(child);

            // Skip invisible or empty elements
            if (!info.name.empty() || !info.automationId.empty() || !info.value.empty()) {
                if (!first) json << ",";
                first = false;
                json << "{"
                     << "\"name\":\"" << EscapeJson(WStringToString(info.name)) << "\","
                     << "\"automationId\":\"" << EscapeJson(WStringToString(info.automationId)) << "\","
                     << "\"controlType\":\"" << EscapeJson(WStringToString(info.controlType)) << "\","
                     << "\"className\":\"" << EscapeJson(WStringToString(info.className)) << "\","
                     << "\"value\":\"" << EscapeJson(WStringToString(info.value)) << "\","
                     << "\"boundingRectangle\":" << RectToJson(info.boundingRect)
                     << "}";
            }

            EnumerateElements(child, walker, depth + 1, json, first);

            CComPtr<IUIAutomationElement> next;
            walker->GetNextSiblingElement(child, &next);
            child = next;
        }
    }

    ElementInfo GetElementInfo(IUIAutomationElement* element) {
        ElementInfo info;

        CComBSTR bstrName;
        if (SUCCEEDED(element->get_CurrentName(&bstrName)) && bstrName) {
            info.name = std::wstring(bstrName, SysStringLen(bstrName));
        }

        CComBSTR bstrAutomationId;
        if (SUCCEEDED(element->get_CurrentAutomationId(&bstrAutomationId)) && bstrAutomationId) {
            info.automationId = std::wstring(bstrAutomationId, SysStringLen(bstrAutomationId));
        }

        CComBSTR bstrCtrlType;
        if (SUCCEEDED(element->get_CurrentLocalizedControlType(&bstrCtrlType)) && bstrCtrlType) {
            info.controlType = std::wstring(bstrCtrlType, SysStringLen(bstrCtrlType));
        }

        CComBSTR bstrClassName;
        if (SUCCEEDED(element->get_CurrentClassName(&bstrClassName)) && bstrClassName) {
            info.className = std::wstring(bstrClassName, SysStringLen(bstrClassName));
        }

        element->get_CurrentBoundingRectangle(&info.boundingRect);

        // Try to get value
        CComPtr<IUnknown> unknown;
        HRESULT hr = element->GetCurrentPattern(UIA_ValuePatternId, &unknown);
        if (SUCCEEDED(hr) && unknown) {
            CComPtr<IUIAutomationValuePattern> valuePattern;
            hr = unknown->QueryInterface(IID_IUIAutomationValuePattern, (void**)&valuePattern);
            if (SUCCEEDED(hr) && valuePattern) {
                CComBSTR bstrValue;
                if (SUCCEEDED(valuePattern->get_CurrentValue(&bstrValue)) && bstrValue) {
                    info.value = std::wstring(bstrValue, SysStringLen(bstrValue));
                }
            }
        }

        return info;
    }

private:
    HWND FindTargetWindow(const std::string& appName) {
        HWND found = nullptr;
        std::string name = appName;
        FindData findData = {name, found};

        EnumWindows([](HWND hwnd, LPARAM lParam) -> BOOL {
            auto& data = *reinterpret_cast<FindData*>(lParam);
            if (!IsWindowVisible(hwnd)) return TRUE;
            int len = GetWindowTextLengthW(hwnd);
            if (len == 0) return TRUE;

            std::wstring title(len + 1, L'\0');
            GetWindowTextW(hwnd, &title[0], len + 1);
            title.resize(len);
            std::string titleA = WStringToString(title);

            if (ContainsIgnoreCase(titleA, data.appName)) {
                data.result = hwnd;
                return FALSE;
            }

            DWORD pid = 0;
            GetWindowThreadProcessId(hwnd, &pid);
            HANDLE hProcess = OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, FALSE, pid);
            if (hProcess) {
                wchar_t exeName[MAX_PATH] = {0};
                DWORD size = MAX_PATH;
                if (QueryFullProcessImageNameW(hProcess, 0, exeName, &size)) {
                    std::wstring fullPath(exeName);
                    auto pos = fullPath.find_last_of(L"\\/");
                    std::wstring processName;
                    if (pos != std::wstring::npos)
                        processName = fullPath.substr(pos + 1);
                    auto dotPos = processName.find_last_of(L".");
                    if (dotPos != std::wstring::npos)
                        processName = processName.substr(0, dotPos);

                    std::wstring wAppName(data.appName.begin(), data.appName.end());
                    if (_wcsicmp(processName.c_str(), wAppName.c_str()) == 0) {
                        data.result = hwnd;
                        CloseHandle(hProcess);
                        return FALSE;
                    }
                }
                CloseHandle(hProcess);
            }

            return TRUE;
        }, (LPARAM)&findData);

        return found;
    }

    std::string InjectIntoWindow(HWND hwnd, const std::string& label, const std::string& value) {
        CComPtr<IUIAutomationElement> rootElement;
        HRESULT hr = _automation->ElementFromHandle(reinterpret_cast<UIA_HWND>(hwnd), &rootElement);
        if (FAILED(hr) || !rootElement) {
            return "{\"success\":false,\"error\":\"Could not get root element\"}";
        }

        std::wstring labelW(label.begin(), label.end());
        std::string labelNorm = NormalizeArabic(NormalizeLabel(label));

        CComPtr<IUIAutomationElement> foundEdit = FindEditNearLabel(rootElement, labelNorm);
        if (!foundEdit) {
            return "{\"success\":false,\"error\":\"No edit field found near label: " + EscapeJson(label) + "\"}";
        }

        return SetElementValue(foundEdit, value);
    }

    CComPtr<IUIAutomationElement> FindEditNearLabel(IUIAutomationElement* root, const std::string& labelNorm) {
        CComPtr<IUIAutomationCondition> trueCond;
        _automation->CreateTrueCondition(&trueCond);

        CComPtr<IUIAutomationTreeWalker> walker;
        _automation->CreateTreeWalker(trueCond, &walker);

        CComPtr<IUIAutomationElement> found;
        SearchElement(root, labelNorm, walker, 0, &found);
        return found;
    }

    void SearchElement(IUIAutomationElement* element, const std::string& labelNorm,
                       IUIAutomationTreeWalker* walker, int depth, IUIAutomationElement** result) {
        if (*result || depth > 10) return;

        CComPtr<IUIAutomationElement> child;
        walker->GetFirstChildElement(element, &child);

        while (child && !*result) {
            // Get element name
            CComBSTR bstrName;
            HRESULT hr = child->get_CurrentName(&bstrName);
            if (SUCCEEDED(hr) && bstrName) {
                std::wstring nameW(bstrName, SysStringLen(bstrName));
                std::string nameA = WStringToString(nameW);
                std::string nameNorm = NormalizeArabic(nameA);

                // Check if this element's name contains our label
                if (ContainsIgnoreCase(nameNorm, labelNorm)) {
                    CComBSTR bstrCtrlType;
                    child->get_CurrentLocalizedControlType(&bstrCtrlType);
                    std::wstring ctrlType(bstrCtrlType, bstrCtrlType ? SysStringLen(bstrCtrlType) : 0);
                    std::string ctrlTypeA = WStringToString(ctrlType);

                    // If this element itself is editable, use it directly
                    if (IsEditable(child)) {
                        *result = child.Detach();
                        return;
                    }

                    // If it's a label/text element, find nearby edit field
                    if (ctrlType == L"text" || ctrlType == L"label" || ctrlType == L"heading") {
                        // Strategy 1: next sibling
                        CComPtr<IUIAutomationElement> sibling;
                        walker->GetNextSiblingElement(child, &sibling);
                        if (sibling && IsEditable(sibling)) {
                            *result = sibling.Detach();
                            return;
                        }

                        // Strategy 2: search entire subtree of parent
                        CComPtr<IUIAutomationElement> parent;
                        walker->GetParentElement(child, &parent);
                        if (parent) {
                            CComPtr<IUIAutomationElement> editInParent = FindEditInChildren(parent, walker, 0);
                            if (editInParent) {
                                *result = editInParent.Detach();
                                return;
                            }
                        }
                    }
                }
            }

            // Also check if the element itself is the edit field with matching name
            if (!*result) {
                if (IsEditable(child)) {
                    CComBSTR bstrName2;
                    if (SUCCEEDED(child->get_CurrentName(&bstrName2)) && bstrName2) {
                        std::wstring nameW2(bstrName2, SysStringLen(bstrName2));
                        std::string nameA2 = WStringToString(nameW2);
                        std::string nameNorm2 = NormalizeArabic(nameA2);
                        if (ContainsIgnoreCase(nameNorm2, labelNorm)) {
                            *result = child.Detach();
                            return;
                        }
                    }
                }
            }

            SearchElement(child, labelNorm, walker, depth + 1, result);
            
            CComPtr<IUIAutomationElement> nextChild;
            walker->GetNextSiblingElement(child, &nextChild);
            child = nextChild;
        }
    }

    CComPtr<IUIAutomationElement> FindEditInChildren(IUIAutomationElement* parent, IUIAutomationTreeWalker* walker, int depth) {
        if (depth > 3) return nullptr;

        CComPtr<IUIAutomationElement> child;
        walker->GetFirstChildElement(parent, &child);

        while (child) {
            if (IsEditable(child))
                return child;

            auto found = FindEditInChildren(child, walker, depth + 1);
            if (found) return found;

            CComPtr<IUIAutomationElement> next;
            walker->GetNextSiblingElement(child, &next);
            child = next;
        }

        return nullptr;
    }

    bool IsEditable(IUIAutomationElement* element) {
        CComBSTR bstrCtrlType;
        element->get_CurrentLocalizedControlType(&bstrCtrlType);
        std::wstring ctrlType(bstrCtrlType, bstrCtrlType ? SysStringLen(bstrCtrlType) : 0);
        return ctrlType == L"edit" || ctrlType == L"combobox" || ctrlType == L"text";
    }

    std::string SetElementValue(IUIAutomationElement* element, const std::string& value) {
        // Try ValuePattern first
        CComPtr<IUnknown> unknown;
        HRESULT hr = element->GetCurrentPattern(UIA_ValuePatternId, &unknown);
        if (SUCCEEDED(hr) && unknown) {
            CComPtr<IUIAutomationValuePattern> valuePattern;
            hr = unknown->QueryInterface(IID_IUIAutomationValuePattern, (void**)&valuePattern);
            if (SUCCEEDED(hr) && valuePattern) {
                CComBSTR bstrValue(value.c_str());
                hr = valuePattern->SetValue(bstrValue);
                if (SUCCEEDED(hr))
                    return "{\"success\":true,\"method\":\"ValuePattern\"}";
            }
        }

        // Fallback 1: try SetFocus + SendMessage (native Win32)
        element->SetFocus();
        Sleep(50);

        HWND hwnd = nullptr;
        element->get_CurrentNativeWindowHandle((UIA_HWND*)&hwnd);
        if (hwnd) {
            std::wstring valueW(value.begin(), value.end());
            SendMessageW(hwnd, WM_SETTEXT, 0, (LPARAM)valueW.c_str());
            return "{\"success\":true,\"method\":\"SendMessage\"}";
        }

        // Fallback 2: keyboard simulation for cross-platform UI (Flutter, Qt, etc.)
        // Focus already set above, now type the text via keystrokes
        Sleep(100);

        // Clear existing text: Ctrl+A, Delete
        INPUT inputs[4] = {};
        // Ctrl down
        inputs[0].type = INPUT_KEYBOARD;
        inputs[0].ki.wVk = VK_CONTROL;
        // A down
        inputs[1].type = INPUT_KEYBOARD;
        inputs[1].ki.wVk = 'A';
        // A up
        inputs[2].type = INPUT_KEYBOARD;
        inputs[2].ki.wVk = 'A';
        inputs[2].ki.dwFlags = KEYEVENTF_KEYUP;
        // Ctrl up
        inputs[3].type = INPUT_KEYBOARD;
        inputs[3].ki.wVk = VK_CONTROL;
        inputs[3].ki.dwFlags = KEYEVENTF_KEYUP;
        SendInput(4, inputs, sizeof(INPUT));
        Sleep(50);
        // Delete
        INPUT delInput = {};
        delInput.type = INPUT_KEYBOARD;
        delInput.ki.wVk = VK_DELETE;
        SendInput(1, &delInput, sizeof(INPUT));
        Sleep(50);
        delInput.ki.dwFlags = KEYEVENTF_KEYUP;
        SendInput(1, &delInput, sizeof(INPUT));
        Sleep(30);

        // Type each character (supports Unicode/Arabic via KEYEVENTF_UNICODE)
        std::wstring valueW(value.begin(), value.end());
        for (wchar_t ch : valueW) {
            INPUT unicodeInputs[2] = {};
            // Key down with Unicode
            unicodeInputs[0].type = INPUT_KEYBOARD;
            unicodeInputs[0].ki.wScan = ch;
            unicodeInputs[0].ki.dwFlags = KEYEVENTF_UNICODE;
            // Key up with Unicode
            unicodeInputs[1].type = INPUT_KEYBOARD;
            unicodeInputs[1].ki.wScan = ch;
            unicodeInputs[1].ki.dwFlags = KEYEVENTF_UNICODE | KEYEVENTF_KEYUP;
            SendInput(2, unicodeInputs, sizeof(INPUT));
            Sleep(3);
        }

        return "{\"success\":true,\"method\":\"KeyboardSimulation\"}";
    }
};

// Escape string for JSON
std::string EscapeJson(const std::string& s) {
    std::string result;
    result.reserve(s.length());
    for (char c : s) {
        switch (c) {
            case '"': result += "\\\""; break;
            case '\\': result += "\\\\"; break;
            case '\b': result += "\\b"; break;
            case '\f': result += "\\f"; break;
            case '\n': result += "\\n"; break;
            case '\r': result += "\\r"; break;
            case '\t': result += "\\t"; break;
            default:
                if ((unsigned char)c < 0x20) {
                    char buf[8];
                    snprintf(buf, sizeof(buf), "\\u%04x", (unsigned char)c);
                    result += buf;
                } else {
                    result += c;
                }
        }
    }
    return result;
}

void OutputJson(const std::string& json) {
    std::cout << json << std::endl;
}

void Log(const std::string& msg) {
    std::cerr << "[Automation] " << msg << std::endl;
}

// Parse a simple JSON value by key
std::string GetJsonValue(const std::string& json, const std::string& key) {
    std::string search = "\"" + key + "\":\"";
    auto start = json.find(search);
    if (start == std::string::npos) {
        // Try without quotes (for non-string values)
        search = "\"" + key + "\":";
        start = json.find(search);
        if (start == std::string::npos) return "";
        start += search.length();
        auto end = json.find_first_of(",}", start);
        if (end == std::string::npos) return "";
        return json.substr(start, end - start);
    }
    start += search.length();
    auto end = json.find("\"", start);
    if (end == std::string::npos) return "";
    return json.substr(start, end - start);
}

int main() {
    // Set console output to UTF-8
    SetConsoleOutputCP(CP_UTF8);
    SetConsoleCP(CP_UTF8);

    Log("C++ Automation Engine started");

    AutomationEngine engine;
    if (!engine.IsValid()) {
        Log("Failed to initialize UIAutomation");
        OutputJson("{\"success\":false,\"error\":\"UIAutomation initialization failed\"}");
        return 1;
    }

    std::string line;
    while (std::getline(std::cin, line)) {
        if (line.empty()) continue;

        std::string action = GetJsonValue(line, "action");

        if (action == "list_apps") {
            OutputJson(engine.ListApps());
        }
        else if (action == "scan") {
            std::string appName = GetJsonValue(line, "targetApp");
            if (appName.empty()) {
                OutputJson("{\"success\":false,\"error\":\"Missing targetApp\"}");
            } else {
                OutputJson(engine.ScanWindow(appName));
            }
        }
        else if (action == "find_fields") {
            std::string appName = GetJsonValue(line, "targetApp");
            std::string labels = GetJsonValue(line, "selector");
            // The selector is a JSON object, extract label field from it
            std::string labelKey = "\"label\":\"";
            auto labelStart = labels.find(labelKey);
            std::string labelsCsv;
            if (labelStart != std::string::npos) {
                labelStart += labelKey.length();
                auto labelEnd = labels.find("\"", labelStart);
                if (labelEnd != std::string::npos) {
                    labelsCsv = labels.substr(labelStart, labelEnd - labelStart);
                }
            }
            if (appName.empty() || labelsCsv.empty()) {
                OutputJson("{\"success\":false,\"data\":[],\"error\":\"Missing targetApp or label\"}");
            } else {
                OutputJson(engine.FindFieldsByLabels(appName, labelsCsv));
            }
        }
        else if (action == "inject") {
            std::string appName = GetJsonValue(line, "targetApp");
            std::string label = GetJsonValue(line, "label");
            std::string value = GetJsonValue(line, "value");
            if (appName.empty() || label.empty()) {
                OutputJson("{\"success\":false,\"error\":\"Missing targetApp or label\"}");
            } else {
                OutputJson(engine.InjectIntoApp(appName, label, value));
            }
        }
        else {
            OutputJson("{\"success\":false,\"error\":\"Unknown action: " + EscapeJson(action) + "\"}");
        }
    }

    return 0;
}