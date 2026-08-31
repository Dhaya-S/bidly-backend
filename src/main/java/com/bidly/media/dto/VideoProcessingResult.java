package com.bidly.media.dto;

import java.io.File;

/**
 * Encapsulates the output files and metadata resulting from FFmpeg video processing.
 * Implements AutoCloseable to ensure temporary files can be cleaned up reliably.
 */
public class VideoProcessingResult implements AutoCloseable {

    private File sourceTempFile;
    private File optimizedVideoFile;
    private File thumbnailFile;
    private VideoMetadata sourceMetadata;
    private int outputWidth;
    private int outputHeight;
    private double outputDurationSeconds;
    private String outputVideoCodec;
    private String outputAudioCodec;
    private long outputFileSize;
    private boolean fastStartVerified;

    public VideoProcessingResult() {}

    public File getSourceTempFile() { return sourceTempFile; }
    public void setSourceTempFile(File sourceTempFile) { this.sourceTempFile = sourceTempFile; }

    public File getOptimizedVideoFile() { return optimizedVideoFile; }
    public void setOptimizedVideoFile(File optimizedVideoFile) { this.optimizedVideoFile = optimizedVideoFile; }

    public File getThumbnailFile() { return thumbnailFile; }
    public void setThumbnailFile(File thumbnailFile) { this.thumbnailFile = thumbnailFile; }

    public VideoMetadata getSourceMetadata() { return sourceMetadata; }
    public void setSourceMetadata(VideoMetadata sourceMetadata) { this.sourceMetadata = sourceMetadata; }

    public int getOutputWidth() { return outputWidth; }
    public void setOutputWidth(int outputWidth) { this.outputWidth = outputWidth; }

    public int getOutputHeight() { return outputHeight; }
    public void setOutputHeight(int outputHeight) { this.outputHeight = outputHeight; }

    public double getOutputDurationSeconds() { return outputDurationSeconds; }
    public void setOutputDurationSeconds(double outputDurationSeconds) { this.outputDurationSeconds = outputDurationSeconds; }

    public String getOutputVideoCodec() { return outputVideoCodec; }
    public void setOutputVideoCodec(String outputVideoCodec) { this.outputVideoCodec = outputVideoCodec; }

    public String getOutputAudioCodec() { return outputAudioCodec; }
    public void setOutputAudioCodec(String outputAudioCodec) { this.outputAudioCodec = outputAudioCodec; }

    public long getOutputFileSize() { return outputFileSize; }
    public void setOutputFileSize(long outputFileSize) { this.outputFileSize = outputFileSize; }

    public boolean isFastStartVerified() { return fastStartVerified; }
    public void setFastStartVerified(boolean fastStartVerified) { this.fastStartVerified = fastStartVerified; }

    /**
     * Clean up all temporary files created during processing.
     */
    @Override
    public void close() {
        safeDelete(sourceTempFile);
        safeDelete(optimizedVideoFile);
        safeDelete(thumbnailFile);
    }

    private void safeDelete(File file) {
        if (file != null && file.exists()) {
            try {
                file.delete();
            } catch (Exception ignored) {}
        }
    }

    @Override
    public String toString() {
        return "VideoProcessingResult{" +
                "outputResolution=" + outputWidth + "x" + outputHeight +
                ", outputDuration=" + String.format("%.2f", outputDurationSeconds) + "s" +
                ", outputVideoCodec='" + outputVideoCodec + '\'' +
                ", outputAudioCodec='" + outputAudioCodec + '\'' +
                ", outputFileSize=" + String.format("%.2f", outputFileSize / (1024.0 * 1024.0)) + "MB" +
                ", fastStartVerified=" + fastStartVerified +
                '}';
    }
}
