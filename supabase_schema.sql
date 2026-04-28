-- Create the expenses table
create table expenses (
  id uuid default uuid_generate_v4() primary key,
  title text not null,
  amount numeric not null,
  date date not null,
  category text not null,
  user_id uuid references auth.users not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable Row Level Security (RLS)
alter table expenses enable row level security;

-- Create policy for users to see only their own expenses
create policy "Users can view their own expenses."
  on expenses for select
  using ( auth.uid() = user_id );

-- Create policy for users to insert their own expenses
create policy "Users can insert their own expenses."
  on expenses for insert
  with check ( auth.uid() = user_id );

-- Create policy for users to update their own expenses
create policy "Users can update their own expenses."
  on expenses for update
  using ( auth.uid() = user_id );

-- Create policy for users to delete their own expenses
create policy "Users can delete their own expenses."
  on expenses for delete
  using ( auth.uid() = user_id );
