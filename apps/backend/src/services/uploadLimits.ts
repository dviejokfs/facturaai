/**
 * Shared upload-size enforcement for invoice upload endpoints.
 * Centralized so limit + error shape stay in sync across routes.
 */

export const MAX_UPLOAD_BYTES = 20 * 1024 * 1024; // 20 MB

export type UploadLimitError = {
  error: "file_too_large";
  message: string;
  limitBytes: number;
  limitMb: number;
  receivedBytes: number;
  receivedMb: number;
};

function formatMb(bytes: number): string {
  return (bytes / (1024 * 1024)).toFixed(1);
}

/**
 * Builds the 413 payload with precise actual size so the client can show
 * the user exactly how much they exceeded the limit by.
 */
export function tooLargePayload(receivedBytes: number): UploadLimitError {
  const limitMb = MAX_UPLOAD_BYTES / (1024 * 1024);
  const receivedMb = Number(formatMb(receivedBytes));
  return {
    error: "file_too_large",
    message: `File is ${formatMb(receivedBytes)} MB. Maximum upload size is ${limitMb} MB.`,
    limitBytes: MAX_UPLOAD_BYTES,
    limitMb,
    receivedBytes,
    receivedMb,
  };
}
