#include "ITKBridgeUtils.h"

#include <algorithm>
#include <cctype>
#include <cstring>
#include <iomanip>
#include <sstream>
#include <sys/stat.h>

namespace {

bool hasSuffix(const std::string &value, const std::string &suffix) {
    if (suffix.size() > value.size()) {
        return false;
    }
    return std::equal(suffix.rbegin(), suffix.rend(), value.rbegin());
}

std::string toLower(const std::string &value) {
    std::string lower(value);
    std::transform(lower.begin(), lower.end(), lower.begin(), [](unsigned char c) {
        return static_cast<char>(std::tolower(c));
    });
    return lower;
}

} // namespace

// ---- File helpers ----

bool isDirectory(const char *path) {
    if (!path) {
        return false;
    }
    struct stat s;
    if (stat(path, &s) != 0) {
        return false;
    }
    return (s.st_mode & S_IFDIR) != 0;
}

bool isNiftiPath(const char *path) {
    if (!path) {
        return false;
    }
    const std::string lower = toLower(path);
    return hasSuffix(lower, ".nii") || hasSuffix(lower, ".nii.gz");
}

bool isDicomPath(const char *path) {
    if (!path) {
        return false;
    }
    const std::string lower = toLower(path);
    return hasSuffix(lower, ".dcm");
}

// ---- String helpers ----

void writeError(char *buffer, int bufferLength, const char *message) {
    if (!buffer || bufferLength <= 0) {
        return;
    }
    if (!message) {
        buffer[0] = '\0';
        return;
    }
    const size_t len = std::strlen(message);
    const size_t toCopy =
        (len + 1 < static_cast<size_t>(bufferLength))
            ? len
            : static_cast<size_t>(bufferLength - 1);
    std::memcpy(buffer, message, toCopy);
    buffer[toCopy] = '\0';
}

std::string escapeJSON(const std::string &input) {
    std::string output;
    output.reserve(input.size());
    for (char c : input) {
        switch (c) {
        case '"': output += "\\\""; break;
        case '\\': output += "\\\\"; break;
        case '\n': output += "\\n"; break;
        case '\r': output += "\\r"; break;
        case '\t': output += "\\t"; break;
        default: output += c; break;
        }
    }
    return output;
}

std::string normalizeTagKey(const std::string &key) {
    std::string normalized = key;
    std::replace(normalized.begin(), normalized.end(), '|', ',');
    return normalized;
}

std::string formatNumber(double value, int precision) {
    std::ostringstream stream;
    stream.setf(std::ios::fixed);
    stream << std::setprecision(precision) << value;
    return stream.str();
}

// ---- JSON helpers ----

std::string jsonNumber(double value) {
    return formatNumber(value, 17);
}

std::string jsonStringValue(const std::string &value) {
    return "\"" + escapeJSON(value) + "\"";
}

std::string jsonArrayFromStrings(const std::vector<std::string> &values) {
    std::string json = "[";
    for (size_t i = 0; i < values.size(); ++i) {
        if (i > 0) { json += ","; }
        json += "\"";
        json += escapeJSON(values[i]);
        json += "\"";
    }
    json += "]";
    return json;
}

std::string jsonObjectField(const std::string &key, const std::string &value, bool &firstField) {
    std::string out;
    if (!firstField) { out += ","; }
    firstField = false;
    out += "\"";
    out += escapeJSON(key);
    out += "\":";
    out += value;
    return out;
}

std::string jsonStringField(const std::string &key, const std::string &value, bool &firstField) {
    std::string out;
    if (!firstField) { out += ","; }
    firstField = false;
    out += "\"";
    out += escapeJSON(key);
    out += "\":\"";
    out += escapeJSON(value);
    out += "\"";
    return out;
}
