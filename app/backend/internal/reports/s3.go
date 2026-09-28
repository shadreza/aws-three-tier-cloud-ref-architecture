package reports

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"io"
	"path"
	"slices"
	"strings"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/aws/aws-sdk-go-v2/service/s3/types"
)

// S3API is the part of the S3 client we use. The real client satisfies it,
// and tests can pass a fake.
type S3API interface {
	PutObject(ctx context.Context, in *s3.PutObjectInput, opts ...func(*s3.Options)) (*s3.PutObjectOutput, error)
	GetObject(ctx context.Context, in *s3.GetObjectInput, opts ...func(*s3.Options)) (*s3.GetObjectOutput, error)
	ListObjectsV2(ctx context.Context, in *s3.ListObjectsV2Input, opts ...func(*s3.Options)) (*s3.ListObjectsV2Output, error)
}

// S3 keeps reports as objects in a bucket, under Prefix (for example
// "reports/"). On AWS, every API and rollup task shares the same bucket,
// which a local folder cannot do across containers.
type S3 struct {
	Client S3API
	Bucket string
	Prefix string
}

func (s S3) key(name string) string {
	return path.Join(s.Prefix, name)
}

func (s S3) Save(ctx context.Context, name string, data []byte) error {
	if !ValidName(name) {
		return ErrInvalidName
	}
	// A PUT replaces the whole object at once, so readers never see half a
	// report. No temp file needed here.
	_, err := s.Client.PutObject(ctx, &s3.PutObjectInput{
		Bucket:      aws.String(s.Bucket),
		Key:         aws.String(s.key(name)),
		Body:        bytes.NewReader(data),
		ContentType: aws.String("text/csv; charset=utf-8"),
	})
	if err != nil {
		return fmt.Errorf("upload report %s: %w", name, err)
	}
	return nil
}

func (s S3) List(ctx context.Context) ([]string, error) {
	prefix := strings.TrimSuffix(s.Prefix, "/")
	if prefix != "" {
		prefix += "/"
	}

	names := []string{}
	pages := s3.NewListObjectsV2Paginator(s.Client, &s3.ListObjectsV2Input{
		Bucket: aws.String(s.Bucket),
		Prefix: aws.String(prefix),
	})
	for pages.HasMorePages() {
		page, err := pages.NextPage(ctx)
		if err != nil {
			return nil, fmt.Errorf("list reports: %w", err)
		}
		for _, obj := range page.Contents {
			name := strings.TrimPrefix(aws.ToString(obj.Key), prefix)
			if ValidName(name) {
				names = append(names, name)
			}
		}
	}
	slices.Sort(names)
	slices.Reverse(names)
	return names, nil
}

func (s S3) Open(ctx context.Context, name string) (io.ReadCloser, error) {
	if !ValidName(name) {
		return nil, ErrInvalidName
	}
	out, err := s.Client.GetObject(ctx, &s3.GetObjectInput{
		Bucket: aws.String(s.Bucket),
		Key:    aws.String(s.key(name)),
	})
	var missing *types.NoSuchKey
	if errors.As(err, &missing) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("download report %s: %w", name, err)
	}
	return out.Body, nil
}
