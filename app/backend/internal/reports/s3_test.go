package reports

import (
	"bytes"
	"context"
	"io"
	"slices"
	"strings"
	"testing"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/aws/aws-sdk-go-v2/service/s3/types"
)

// fakeS3 keeps objects in a map. It returns one key per page so the test
// also covers paging.
type fakeS3 struct {
	objects map[string][]byte
}

func (f *fakeS3) PutObject(ctx context.Context, in *s3.PutObjectInput, _ ...func(*s3.Options)) (*s3.PutObjectOutput, error) {
	b, _ := io.ReadAll(in.Body)
	f.objects[aws.ToString(in.Key)] = b
	return &s3.PutObjectOutput{}, nil
}

func (f *fakeS3) GetObject(ctx context.Context, in *s3.GetObjectInput, _ ...func(*s3.Options)) (*s3.GetObjectOutput, error) {
	b, ok := f.objects[aws.ToString(in.Key)]
	if !ok {
		return nil, &types.NoSuchKey{}
	}
	return &s3.GetObjectOutput{Body: io.NopCloser(bytes.NewReader(b))}, nil
}

func (f *fakeS3) ListObjectsV2(ctx context.Context, in *s3.ListObjectsV2Input, _ ...func(*s3.Options)) (*s3.ListObjectsV2Output, error) {
	keys := []string{}
	for k := range f.objects {
		if strings.HasPrefix(k, aws.ToString(in.Prefix)) && k > aws.ToString(in.StartAfter) && k > aws.ToString(in.ContinuationToken) {
			keys = append(keys, k)
		}
	}
	slices.Sort(keys)
	if len(keys) == 0 {
		return &s3.ListObjectsV2Output{IsTruncated: aws.Bool(false)}, nil
	}
	out := &s3.ListObjectsV2Output{Contents: []types.Object{{Key: aws.String(keys[0])}}}
	if len(keys) > 1 {
		out.IsTruncated = aws.Bool(true)
		out.NextContinuationToken = aws.String(keys[0])
	}
	return out, nil
}

func TestS3(t *testing.T) {
	ctx := context.Background()
	fake := &fakeS3{objects: map[string][]byte{
		"other/2026-01-01.csv": []byte("not ours"),
		"reports/notes.txt":    []byte("not a report"),
	}}
	store := S3{Client: fake, Bucket: "b", Prefix: "reports/"}

	for _, n := range []string{"2026-01-30.csv", "2026-01-31.csv"} {
		if err := store.Save(ctx, n, []byte(n)); err != nil {
			t.Fatalf("save %s: %v", n, err)
		}
	}
	if _, ok := fake.objects["reports/2026-01-31.csv"]; !ok {
		t.Fatalf("object not saved under the prefix: %v", fake.objects)
	}

	names, err := store.List(ctx)
	if err != nil {
		t.Fatalf("list: %v", err)
	}
	if want := []string{"2026-01-31.csv", "2026-01-30.csv"}; !slices.Equal(names, want) {
		t.Errorf("List = %v, want %v", names, want)
	}

	f, err := store.Open(ctx, "2026-01-30.csv")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	defer f.Close()
	if b, _ := io.ReadAll(f); string(b) != "2026-01-30.csv" {
		t.Errorf("content = %q", b)
	}

	if _, err := store.Open(ctx, "2026-02-01.csv"); err != ErrNotFound {
		t.Errorf("missing report: got %v, want ErrNotFound", err)
	}
	if err := store.Save(ctx, "../x.csv", nil); err != ErrInvalidName {
		t.Errorf("bad name: got %v, want ErrInvalidName", err)
	}
}
