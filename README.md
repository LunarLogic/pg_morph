# PgMorph

PgMorph gives you a way to handle DB consistency for polymorphic relations and is based on postgreSQL inheritance and partitioning features.

## Installation

Add this line to your application's Gemfile:

    gem 'pg_morph'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install pg_morph

## Usage

Let's say you have a `Like` class and it's in polymorphic relation with `Post` and `Comment` classes. You can't add foreign keys for those relations, and there's where PgMorph comes.

By adding migration:

    add_polymorphic_foreign_key :likes, :comments, column: :likeable

PgMorph creates a partition table named `likes_comments` which inherits from `likes` table, sets foreign key on it and redirects all inserts to `likes` to this partition table if `likeable_type` is `Like`. It's done by using before insert trigger.

You will have to add polymorphic foreign key on all related tables and each time new relation is added, before insert trigger function will be updated to reflect all defined relations and redirect new records to proper partitions.

From the Rails point of view it's totally transparent, so all inserts, updates and selections work as they were on original `likes` table.

You can remove polymorphic foreign keys with below migration:

    remove_polymorphic_foreign_key :likes, comments, column: :likeable

Because it means that whole partition table would be removed, you will be forbidden to do that if partition table contains any data.

## Issues

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
