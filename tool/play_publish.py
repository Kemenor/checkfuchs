#!/usr/bin/env python3
"""Push the Play Store listing from the fastlane/metadata tree.

Uses the Google Play Android Publisher API directly (same surface fastlane
`supply` drives), so no Ruby/fastlane needed. Reads:

    fastlane/metadata/android/<locale>/title.txt
                                       short_description.txt
                                       full_description.txt
                                       images/phoneScreenshots/*.png
                                       images/icon.png            (optional)
                                       images/featureGraphic.png  (optional)

By default this is a DRY RUN: it opens an edit, uploads everything to validate
it, then DISCARDS the edit (no changes saved). Pass --commit to actually save
the listing as a draft (changesNotSentForReview — nothing is submitted for
review; you still publish manually in the Console).
"""
import argparse
import os
import sys

from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from googleapiclient.http import MediaFileUpload

KEY = 'fastlane/play-store-key.json'
PKG = 'ch.fuchsnest.checkfuchs'
META = 'fastlane/metadata/android'
SCOPES = ['https://www.googleapis.com/auth/androidpublisher']


def read(path):
    with open(path, encoding='utf-8') as f:
        return f.read().strip()


def locales():
    return sorted(d for d in os.listdir(META)
                  if os.path.isdir(os.path.join(META, d)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--commit', action='store_true',
                    help='save the listing as a draft (default: dry run)')
    args = ap.parse_args()

    creds = service_account.Credentials.from_service_account_file(
        KEY, scopes=SCOPES)
    svc = build('androidpublisher', 'v3', credentials=creds,
                cache_discovery=False)

    edit_id = svc.edits().insert(packageName=PKG, body={}).execute()['id']
    mode = 'COMMIT' if args.commit else 'DRY RUN'
    print('[%s] edit %s' % (mode, edit_id))

    try:
        for loc in locales():
            base = os.path.join(META, loc)
            body = {
                'language': loc,
                'title': read(os.path.join(base, 'title.txt')),
                'shortDescription': read(
                    os.path.join(base, 'short_description.txt')),
                'fullDescription': read(
                    os.path.join(base, 'full_description.txt')),
            }
            svc.edits().listings().update(
                packageName=PKG, editId=edit_id, language=loc,
                body=body).execute()
            print('  listing  %-6s  "%s"' % (loc, body['title']))

            imgdir = os.path.join(base, 'images')
            # single-slot graphics
            for fname, itype in (('icon.png', 'icon'),
                                 ('featureGraphic.png', 'featureGraphic')):
                p = os.path.join(imgdir, fname)
                if os.path.isfile(p):
                    svc.edits().images().deleteall(
                        packageName=PKG, editId=edit_id, language=loc,
                        imageType=itype).execute()
                    svc.edits().images().upload(
                        packageName=PKG, editId=edit_id, language=loc,
                        imageType=itype,
                        media_body=MediaFileUpload(p, mimetype='image/png')
                    ).execute()
                    print('  image    %-6s  %s' % (loc, itype))
            # phone screenshots
            shots = os.path.join(imgdir, 'phoneScreenshots')
            if os.path.isdir(shots):
                files = sorted(f for f in os.listdir(shots)
                               if f.lower().endswith(('.png', '.jpg', '.jpeg')))
                if files:
                    svc.edits().images().deleteall(
                        packageName=PKG, editId=edit_id, language=loc,
                        imageType='phoneScreenshots').execute()
                    for f in files:
                        svc.edits().images().upload(
                            packageName=PKG, editId=edit_id, language=loc,
                            imageType='phoneScreenshots',
                            media_body=MediaFileUpload(
                                os.path.join(shots, f), mimetype='image/png')
                        ).execute()
                    print('  shots    %-6s  %d uploaded' % (loc, len(files)))

        if args.commit:
            try:
                svc.edits().commit(
                    packageName=PKG, editId=edit_id,
                    changesNotSentForReview=True).execute()
            except HttpError as e:
                # A never-published app auto-sends changes for review and
                # rejects the flag; commit plainly in that case.
                if e.resp.status == 400 and 'changesNotSentForReview' in str(
                        e._get_reason()):
                    svc.edits().commit(
                        packageName=PKG, editId=edit_id).execute()
                else:
                    raise
            print('[COMMIT] listing saved — app stays in Draft until you '
                  'publish it in the Console')
        else:
            svc.edits().delete(packageName=PKG, editId=edit_id).execute()
            print('[DRY RUN] edit discarded — nothing saved. '
                  'Re-run with --commit to apply.')
    except HttpError as e:
        try:
            svc.edits().delete(packageName=PKG, editId=edit_id).execute()
        except HttpError:
            pass
        print('API ERROR %s:' % e.resp.status, e._get_reason(), file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
