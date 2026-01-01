#pragma once

#include <string>
#include <vector>

// File helpers
bool isDirectory(const char *path);
bool isNiftiPath(const char *path);
bool isDicomPath(const char *path);

// String helpers
void writeError(char *buffer, int bufferLength, const char *message);
std::string escapeJSON(const std::string &input);
std::string normalizeTagKey(const std::string &key);
std::string formatNumber(double value, int precision = 17);

// JSON helpers
std::string jsonNumber(double value);
std::string jsonStringValue(const std::string &value);
std::string jsonArrayFromStrings(const std::vector<std::string> &values);
std::string jsonObjectField(const std::string &key, const std::string &value, bool &firstField);
std::string jsonStringField(const std::string &key, const std::string &value, bool &firstField);
