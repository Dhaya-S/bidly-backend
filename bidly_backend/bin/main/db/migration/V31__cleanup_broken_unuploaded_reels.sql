-- V31: Mark legacy un-uploaded / failed transcode reels as FAILED so they are not served in feed
UPDATE listings
SET media_processing_status = 'FAILED'
WHERE id IN (
    '53db1699-0dec-4beb-95b5-5ef780d06778',
    '24e7d12b-6284-4178-8ae1-69ab98ccbc50'
);

UPDATE media_jobs
SET status = 'FAILED', error_message = 'Transcode aborted: video file does not exist on R2'
WHERE media_url IN (
    'listings/reels/08b907c3-7891-4780-9850-f9b9b9f38c2d.mp4',
    'listings/reels/dea3d665-6b72-4659-8c15-8d2474bc0706.mp4'
);
