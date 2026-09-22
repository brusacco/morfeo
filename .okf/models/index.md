# Models

Domain models that represent the core entities of the Morfeo platform.

## Content Models

- [Entry](entry.md) - News articles with URL, title, content, sentiment polarity, and social media interaction counts
- [Site](site.md) - News websites being monitored with crawling configuration
- [Topic](topic.md) - Collections of tags for organizing and tracking specific subjects
- [Tag](tag.md) - Labels applied to entries for categorization

## Social Media Models

- [FacebookEntry](facebook_entry.md) - Facebook posts from tracked Pages with comprehensive engagement metrics
- [TwitterPost](twitter_post.md) - Individual tweets from tracked Twitter profiles with engagement metrics
- [TwitterProfile](twitter_profile.md) - Twitter account tracking with profile data and metrics
- [Page](page.md) - Facebook page metadata with follower counts and descriptions

## Analytics Models

- [TopicStatDaily](topic_stat_daily.md) - Daily metrics per topic (entry count, interactions, sentiment breakdown)
- [TitleTopicStatDaily](title_topic_stat_daily.md) - Same metrics but for title-tag analysis
- [Comment](comment.md) - Facebook comments with uid, message, linked to entries

## Other Models

- [User](user.md) - Frontend users with authentication
- [AdminUser](admin_user.md) - ActiveAdmin users with separate authentication
- [Report](report.md) - Generated reports for topics
- [Template](template.md) - Report templates
- [Newspaper](newspaper.md) - Newspaper archival records
- [NewspaperText](newspaper_text.md) - Daily content snapshots
- [Version](version.md) - PaperTrail versioning for audit trails
- [RecentEntry](recent_entry.md) - Recent entries with tagging and word analysis

## Join Models

- [EntryTopic](entry_topic.md) - Join model for Entry-Topic many-to-many relationship
- [EntryTitleTopic](entry_title_topic.md) - Join model for Entry-Topic title-tag relationship
- [UserTopic](user_topic.md) - Join model for User-Topic many-to-many relationship

## Instagram Models

- [InstagramPost](instagram_post.md) - Instagram posts from tracked profiles
- [InstagramProfile](instagram_profile.md) - Instagram account tracking
