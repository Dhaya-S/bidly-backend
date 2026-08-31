package com.bidly.media.dto;

/**
 * Probed technical metadata for an uploaded or processed video.
 */
public class VideoMetadata {
    private int width;
    private int height;
    private double durationSeconds;
    private String videoCodec;
    private String audioCodec;
    private long bitRate;
    private double fps;
    private long fileSizeBytes;
    private String containerFormat;
    private boolean hasAudio;
    private boolean fastStart;

    public VideoMetadata() {}

    public VideoMetadata(int width, int height, double durationSeconds, String videoCodec,
                         String audioCodec, long bitRate, double fps, long fileSizeBytes,
                         String containerFormat, boolean hasAudio, boolean fastStart) {
        this.width = width;
        this.height = height;
        this.durationSeconds = durationSeconds;
        this.videoCodec = videoCodec;
        this.audioCodec = audioCodec;
        this.bitRate = bitRate;
        this.fps = fps;
        this.fileSizeBytes = fileSizeBytes;
        this.containerFormat = containerFormat;
        this.hasAudio = hasAudio;
        this.fastStart = fastStart;
    }

    public int getWidth() { return width; }
    public void setWidth(int width) { this.width = width; }

    public int getHeight() { return height; }
    public void setHeight(int height) { this.height = height; }

    public double getDurationSeconds() { return durationSeconds; }
    public void setDurationSeconds(double durationSeconds) { this.durationSeconds = durationSeconds; }

    public String getVideoCodec() { return videoCodec; }
    public void setVideoCodec(String videoCodec) { this.videoCodec = videoCodec; }

    public String getAudioCodec() { return audioCodec; }
    public void setAudioCodec(String audioCodec) { this.audioCodec = audioCodec; }

    public long getBitRate() { return bitRate; }
    public void setBitRate(long bitRate) { this.bitRate = bitRate; }

    public double getFps() { return fps; }
    public void setFps(double fps) { this.fps = fps; }

    public long getFileSizeBytes() { return fileSizeBytes; }
    public void setFileSizeBytes(long fileSizeBytes) { this.fileSizeBytes = fileSizeBytes; }

    public String getContainerFormat() { return containerFormat; }
    public void setContainerFormat(String containerFormat) { this.containerFormat = containerFormat; }

    public boolean isHasAudio() { return hasAudio; }
    public void setHasAudio(boolean hasAudio) { this.hasAudio = hasAudio; }

    public boolean isFastStart() { return fastStart; }
    public void setFastStart(boolean fastStart) { this.fastStart = fastStart; }

    @Override
    public String toString() {
        return "VideoMetadata{" +
                "resolution=" + width + "x" + height +
                ", duration=" + String.format("%.2f", durationSeconds) + "s" +
                ", vCodec='" + videoCodec + '\'' +
                ", aCodec='" + audioCodec + '\'' +
                ", bitrate=" + (bitRate / 1000) + "kbps" +
                ", fps=" + String.format("%.1f", fps) +
                ", size=" + String.format("%.2f", fileSizeBytes / (1024.0 * 1024.0)) + "MB" +
                ", format='" + containerFormat + '\'' +
                ", hasAudio=" + hasAudio +
                ", fastStart=" + fastStart +
                '}';
    }
}
